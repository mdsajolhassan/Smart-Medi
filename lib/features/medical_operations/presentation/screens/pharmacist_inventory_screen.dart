import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../../core/widgets/smart_medi_drawer.dart';
import '../../../admin_portal/presentation/screens/feedback_screens.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../data/models/inventory_item.dart';

/// Pharmacy portal.
///
/// * Pharmacists manage the pharmacy: add / edit / delete medicines with full
///   details (expiry, batch, manufacturer...), dispense and restock.
/// * Everyone else (doctors, admins) sees the stock read-only.
class PharmacistInventoryScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const PharmacistInventoryScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<PharmacistInventoryScreen> createState() => _PharmacistInventoryScreenState();
}

class _PharmacistInventoryScreenState extends ConsumerState<PharmacistInventoryScreen> {
  final List<InventoryItem> _inventory = [];
  final List<Map<String, dynamic>> _notices = [];
  StreamSubscription? _inventorySub;
  StreamSubscription? _noticeSub;
  bool _loaded = false;

  int _selectedMultiplier = 1;
  final List<int> _multiplierOptions = [1, 2, 5, 10, 20];
  int _dispensedTodayCount = 0;
  String _searchQuery = '';
  bool _filterLowStockOnly = false;

  bool get _canManage => ref.read(authControllerProvider).userProfile?.role == 'pharmacist';

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirestoreCollections.inventory);

  @override
  void initState() {
    super.initState();
    try {
      _inventorySub = _col.snapshots().listen(
        (snap) {
          // Always mirror Firestore exactly (an empty pharmacy shows as empty;
          // nothing is ever re-created automatically).
          final live = snap.docs.map((d) => InventoryItem.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => a.brandName.toLowerCase().compareTo(b.brandName.toLowerCase()));
          if (mounted) {
            setState(() {
              _loaded = true;
              _inventory
                ..clear()
                ..addAll(live);
            });
          }
        },
        onError: (_) {
          if (mounted) setState(() => _loaded = true);
        },
      );

      if (_canManage) {
        _noticeSub = FirebaseFirestore.instance
            .collection(FirestoreCollections.pharmacyNotifications)
            .where('status', isEqualTo: 'unread')
            .snapshots()
            .listen((snap) {
              if (!mounted) return;
              setState(() {
                _notices
                  ..clear()
                  ..addAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
              });
            }, onError: (_) {});
      }
    } catch (_) {
      // Firebase unavailable (tests / offline): show the built-in starter list.
      _inventory.addAll(InventoryItem.defaults);
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    _noticeSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------ stock actions

  /// Applies [delta] atomically on the server so concurrent dispensing from
  /// several devices can't overwrite each other (and stock never goes below 0).
  Future<void> _applyStockDelta(InventoryItem item, int delta) async {
    try {
      final ref = _col.doc(item.id);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = (snap.data()?['stockUnits'] as num?)?.toInt() ?? 0;
        final next = current + delta;
        tx.set(ref, {
          'stockUnits': next < 0 ? 0 : next,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Non-blocking for offline or unit tests
    }
  }

  Future<void> _loadStarterMedicines() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final item in InventoryItem.defaults) {
        batch.set(_col.doc(item.id), {...item.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load starter list: $e')));
      }
    }
  }

  void _changeStock(int index, {required bool dispense}) {
    final item = _inventory[index];
    if (dispense && item.stockUnits <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text('${item.brandName} is out of stock! Cannot dispense.'),
        ),
      );
      return;
    }
    final delta = dispense
        ? -(item.stockUnits >= _selectedMultiplier ? _selectedMultiplier : item.stockUnits)
        : _selectedMultiplier;
    final newStock = item.stockUnits + delta;

    setState(() {
      _inventory[index] = item.copyWith(stockUnits: newStock);
      if (dispense) _dispensedTodayCount += -delta;
    });
    _applyStockDelta(item, delta);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: dispense ? BaustColors.navyDark : BaustColors.successGreen,
        content: Text(
          dispense
              ? 'Dispensed ${-delta} unit(s) of ${item.brandName}. Remaining: $newStock'
              : 'Restocked +$delta unit(s) of ${item.brandName}. Total: $newStock',
        ),
      ),
    );
  }

  Future<void> _deleteMedicine(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove medicine?'),
        content: Text('${item.brandName} will be removed from the pharmacy stock list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BaustColors.emergencyRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _inventory.removeWhere((i) => i.id == item.id));
    try {
      await _col.doc(item.id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
      }
    }
  }

  Future<void> _markNoticeDone(String id) async {
    setState(() => _notices.removeWhere((n) => n['id'] == id));
    try {
      await FirebaseFirestore.instance.collection(FirestoreCollections.pharmacyNotifications).doc(id).update({
        'status': 'done',
        'doneAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ------------------------------------------------------------------ add / edit dialog

  Future<void> _showMedicineDialog({InventoryItem? existing}) async {
    final result = await showDialog<InventoryItem>(
      context: context,
      builder: (_) => _MedicineFormDialog(existing: existing),
    );
    if (result == null) return;

    // Don't create a second entry for a medicine that already exists.
    final name = result.brandName.trim().toLowerCase();
    final duplicate = _inventory.any((i) => i.id != existing?.id && i.brandName.trim().toLowerCase() == name);
    if (duplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            content: Text('${result.brandName} is already in the pharmacy. Edit the existing entry instead.'),
          ),
        );
      }
      return;
    }

    final id = existing?.id ?? InventoryItem.idFor(result.brandName);
    final data = {...result.toMap(), 'updatedAt': FieldValue.serverTimestamp()};
    // Editing details must not overwrite stock that changed meanwhile, unless the pharmacist changed it.
    if (existing != null && result.stockUnits == existing.stockUnits) data.remove('stockUnits');
    try {
      await _col.doc(id).set(data, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.successGreen,
            content: Text(existing == null ? '${result.brandName} added to pharmacy.' : '${result.brandName} updated.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save medicine: $e')));
      }
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    final canManage = _canManage;
    final isRoot = ModalRoute.of(context)?.canPop != true;

    final filteredList = _inventory.where((item) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          item.brandName.toLowerCase().contains(q) ||
          item.genericName.toLowerCase().contains(q) ||
          item.manufacturer.toLowerCase().contains(q) ||
          item.batchNumber.toLowerCase().contains(q);
      return matchesSearch && (!_filterLowStockOnly || item.isLowStock);
    }).toList();

    final totalLowStock = _inventory.where((i) => i.isLowStock).length;
    final totalExpiry = _inventory.where((i) => i.isExpired || i.isExpiringSoon).length;

    final Widget bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canManage && _notices.isNotEmpty) ...[_buildNotices(), const SizedBox(height: 14)],

          Row(
            children: [
              _buildSummaryCard('Medicines', '${_inventory.length}', BaustColors.primaryNavy, Icons.medication),
              const SizedBox(width: 10),
              _buildSummaryCard(
                'Low Stock',
                '$totalLowStock Items',
                totalLowStock > 0 ? BaustColors.emergencyRed : Colors.grey,
                Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                'Expiring / Expired',
                '$totalExpiry Items',
                totalExpiry > 0 ? Colors.orange.shade800 : Colors.grey,
                Icons.event_busy_outlined,
              ),
              if (canManage) ...[
                const SizedBox(width: 10),
                _buildSummaryCard(
                  'Dispensed Today',
                  '$_dispensedTodayCount Units',
                  BaustColors.successGreen,
                  Icons.outbox,
                ),
              ],
            ],
          ),

          if (!canManage) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_outlined, color: BaustColors.primaryNavy, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View only: the pharmacy is managed by the pharmacist.',
                      style: TextStyle(fontSize: 12, color: BaustColors.primaryNavy),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          if (canManage) ...[_buildMultiplierCard(), const SizedBox(height: 14)],

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, generic, manufacturer or batch...',
                    prefixIcon: const Icon(Icons.search, color: BaustColors.primaryNavy),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Show Low Stock Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Switch(
                      value: _filterLowStockOnly,
                      activeThumbColor: BaustColors.emergencyRed,
                      onChanged: (val) => setState(() => _filterLowStockOnly = val),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEDICINES IN STOCK (${filteredList.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: BaustColors.textMuted,
                ),
              ),
              if (canManage)
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Medicine'),
                  onPressed: () => _showMedicineDialog(),
                ),
            ],
          ),

          const SizedBox(height: 10),

          if (_loaded && _inventory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 36, color: BaustColors.textMuted),
                  const SizedBox(height: 8),
                  const Text('No medicines in the pharmacy yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (canManage) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('Load 5 starter medicines'),
                      onPressed: _loadStarterMedicines,
                    ),
                  ],
                ],
              ),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = filteredList[index];
              return FadeSlideIn(
                key: ValueKey('inv_${item.id}'),
                index: index,
                child: _buildItemCard(item, _inventory.indexOf(item), canManage),
              );
            },
          ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return Container(color: BaustColors.surfaceBg, child: bodyContent);
    }

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      drawer: const SmartMediDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            if (!isRoot) {
              return IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              );
            }
            return IconButton(
              tooltip: 'Open navigation drawer',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Image.asset('assets/branding/smart_medi_icon_1024.png', height: 28, width: 28),
            ),
            Flexible(
              child: Text(
                canManage ? 'Pharmacy Inventory (Pharmacist)' : 'Pharmacy Stock (View Only)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (canManage)
            Badge(
              isLabelVisible: _notices.isNotEmpty,
              label: Text('${_notices.length}'),
              offset: const Offset(-6, 6),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Tooltip(message: 'Notices from admin', child: Icon(Icons.notifications_outlined)),
              ),
            ),
          if (canManage && isRoot) const FeedbackIconButton(),
          if (isRoot)
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
        ],
      ),
      body: ResponsiveCenter(maxWidth: 1100, child: bodyContent),
    );
  }

  Widget _buildNotices() {
    return PulseGlow(
      color: Colors.orange,
      borderRadius: 14,
      cycles: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_outlined, color: Colors.orange.shade900, size: 20),
                const SizedBox(width: 8),
                Text(
                  'NOTICES FROM ADMIN (${_notices.length})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final n in _notices)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (n['message'] ?? '').toString(),
                        style: const TextStyle(fontSize: 12, color: BaustColors.textDark),
                      ),
                    ),
                    TextButton(onPressed: () => _markNoticeDone(n['id'] as String), child: const Text('Mark done')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplierCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, color: BaustColors.primaryNavy, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'STOCK ACTION MULTIPLIER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: BaustColors.primaryNavy,
                    ),
                  ),
                ],
              ),
              Text(
                'Step: ±$_selectedMultiplier unit${_selectedMultiplier > 1 ? "s" : ""}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _multiplierOptions.map((mult) {
              final isSelected = _selectedMultiplier == mult;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => setState(() => _selectedMultiplier = mult),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? BaustColors.primaryNavy : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? BaustColors.primaryNavy : Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          '${mult}x',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white : BaustColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item, int index, bool canManage) {
    final isLow = item.isLowStock;
    final expiryColor = item.isExpired
        ? BaustColors.emergencyRed
        : (item.isExpiringSoon ? Colors.orange.shade800 : BaustColors.textMuted);

    Widget detail(IconData icon, String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.only(right: 14, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? BaustColors.textMuted),
          const SizedBox(width: 4),
          Text('$label: ', style: TextStyle(fontSize: 11, color: color ?? BaustColors.textMuted)),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );

    return Card(
      elevation: isLow ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isLow || item.isExpired ? BaustColors.emergencyRed : Colors.grey.shade200,
          width: isLow || item.isExpired ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: isLow ? Colors.red.shade50 : BaustColors.primaryNavy.withValues(alpha: 0.1),
                  child: Icon(
                    isLow ? Icons.error_outline : Icons.healing,
                    color: isLow ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.brandName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        [
                          if (item.genericName.isNotEmpty) item.genericName,
                          if (item.strength.isNotEmpty) item.strength,
                          item.rack,
                        ].join(' • '),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLow ? Colors.red.shade100 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedValueText(
                    '${item.stockUnits} Units',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isLow ? BaustColors.emergencyRed : BaustColors.navyDark,
                    ),
                  ),
                ),
              ],
            ),
            if (isLow || item.isExpired || item.isExpiringSoon) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  if (isLow)
                    Text(
                      'LOW STOCK (below ${item.threshold} units)',
                      style: const TextStyle(
                        color: BaustColors.emergencyRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (item.isExpired || item.isExpiringSoon)
                    Text(
                      item.isExpired ? 'EXPIRED' : 'EXPIRES SOON',
                      style: TextStyle(color: expiryColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ],
            const Divider(height: 18),
            Wrap(
              children: [
                detail(Icons.category_outlined, 'Form', '${item.dosageForm} (${item.unit})'),
                detail(Icons.factory_outlined, 'Manufacturer', item.manufacturer.isEmpty ? '-' : item.manufacturer),
                detail(Icons.qr_code_2, 'Batch', item.batchNumber.isEmpty ? '-' : item.batchNumber),
                detail(Icons.event_outlined, 'Expiry', InventoryItem.formatDate(item.expiryDate), color: expiryColor),
              ],
            ),
            if (item.notes.isNotEmpty)
              Text(
                item.notes,
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: BaustColors.textMuted),
              ),
            if (canManage) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Edit details',
                    icon: const Icon(Icons.edit_outlined, size: 18, color: BaustColors.primaryNavy),
                    onPressed: () => _showMedicineDialog(existing: item),
                  ),
                  IconButton(
                    tooltip: 'Remove medicine',
                    icon: const Icon(Icons.delete_outline, size: 18, color: BaustColors.emergencyRed),
                    onPressed: () => _deleteMedicine(item),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BaustColors.primaryNavy,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.remove, size: 14),
                    label: Text(
                      '-$_selectedMultiplier',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: item.stockUnits > 0 ? () => _changeStock(index, dispense: true) : null,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: BaustColors.successGreen,
                      side: const BorderSide(color: BaustColors.successGreen),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: Text(
                      '+$_selectedMultiplier',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _changeStock(index, dispense: false),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            AnimatedValueText(
              count,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: BaustColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit form with full medicine details, including expiry date.
class _MedicineFormDialog extends StatefulWidget {
  final InventoryItem? existing;
  const _MedicineFormDialog({this.existing});

  @override
  State<_MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends State<_MedicineFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.existing?.brandName ?? '');
  late final _generic = TextEditingController(text: widget.existing?.genericName ?? '');
  late final _strength = TextEditingController(text: widget.existing?.strength ?? '');
  late final _form = TextEditingController(text: widget.existing?.dosageForm ?? 'TABLET');
  late final _unit = TextEditingController(text: widget.existing?.unit ?? 'Tablets');
  late final _manufacturer = TextEditingController(text: widget.existing?.manufacturer ?? '');
  late final _batch = TextEditingController(text: widget.existing?.batchNumber ?? '');
  late final _stock = TextEditingController(text: '${widget.existing?.stockUnits ?? 0}');
  late final _threshold = TextEditingController(text: '${widget.existing?.threshold ?? 10}');
  late final _rack = TextEditingController(text: widget.existing?.rack ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime? _expiry = widget.existing?.expiryDate;

  @override
  void dispose() {
    for (final c in [
      _brand,
      _generic,
      _strength,
      _form,
      _unit,
      _manufacturer,
      _batch,
      _stock,
      _threshold,
      _rack,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
      helpText: 'Expiry date',
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 10);
    String? requiredText(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
    String? number(String? v) => int.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null;

    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Medicine' : 'Edit ${widget.existing!.brandName}'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _brand,
                  decoration: const InputDecoration(labelText: 'Brand name *'),
                  validator: requiredText,
                ),
                gap,
                pair(
                  TextFormField(
                    controller: _generic,
                    decoration: const InputDecoration(labelText: 'Generic name'),
                  ),
                  TextFormField(
                    controller: _strength,
                    decoration: const InputDecoration(labelText: 'Strength'),
                  ),
                ),
                gap,
                pair(
                  TextFormField(
                    controller: _form,
                    decoration: const InputDecoration(labelText: 'Form (TABLET...)'),
                  ),
                  TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Unit (Tablets...)'),
                  ),
                ),
                gap,
                pair(
                  TextFormField(
                    controller: _manufacturer,
                    decoration: const InputDecoration(labelText: 'Manufacturer'),
                  ),
                  TextFormField(
                    controller: _batch,
                    decoration: const InputDecoration(labelText: 'Batch number'),
                  ),
                ),
                gap,
                pair(
                  TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock (units) *'),
                    validator: number,
                  ),
                  TextFormField(
                    controller: _threshold,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Low-stock level *'),
                    validator: number,
                  ),
                ),
                gap,
                TextFormField(
                  controller: _rack,
                  decoration: const InputDecoration(labelText: 'Rack / location'),
                ),
                gap,
                InkWell(
                  onTap: _pickExpiry,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expiry date',
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(InventoryItem.formatDate(_expiry)),
                  ),
                ),
                gap,
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes (storage, supplier...)'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              InventoryItem(
                id: widget.existing?.id ?? '',
                brandName: _brand.text.trim(),
                genericName: _generic.text.trim(),
                strength: _strength.text.trim(),
                dosageForm: _form.text.trim().isEmpty ? 'OTHER' : _form.text.trim().toUpperCase(),
                unit: _unit.text.trim().isEmpty ? 'Units' : _unit.text.trim(),
                manufacturer: _manufacturer.text.trim(),
                batchNumber: _batch.text.trim(),
                expiryDate: _expiry,
                stockUnits: int.parse(_stock.text.trim()),
                threshold: int.parse(_threshold.text.trim()),
                rack: _rack.text.trim().isEmpty ? 'Unassigned' : _rack.text.trim(),
                notes: _notes.text.trim(),
              ),
            );
          },
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
