import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/smart_medi_drawer.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import 'doctor_dashboard_screen.dart';
import 'patient_checkin_log_screen.dart';

class PharmacistInventoryScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const PharmacistInventoryScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<PharmacistInventoryScreen> createState() => _PharmacistInventoryScreenState();
}

class _PharmacistInventoryScreenState extends ConsumerState<PharmacistInventoryScreen> {
  // Top 5 Essential Medicines for BAUST Medical Center (Initial stock: exactly 20 units each)
  final List<Map<String, dynamic>> _inventory = [
    {
      'id': 'med_001',
      'brandName': 'Napa 500mg',
      'genericName': 'Paracetamol',
      'dosageForm': 'TABLET',
      'unit': 'Tablets',
      'stockUnits': 20,
      'threshold': 10,
      'rack': 'Rack A-1 (Analgesics)',
    },
    {
      'id': 'med_002',
      'brandName': 'Seclo 20mg',
      'genericName': 'Omeprazole',
      'dosageForm': 'CAPSULE',
      'unit': 'Capsules',
      'stockUnits': 20,
      'threshold': 10,
      'rack': 'Rack B-1 (Gastric / PPI)',
    },
    {
      'id': 'med_003',
      'brandName': 'Metronidazole 400mg',
      'genericName': 'Metronidazole',
      'dosageForm': 'TABLET',
      'unit': 'Tablets',
      'stockUnits': 20,
      'threshold': 10,
      'rack': 'Rack A-2 (Antimicrobial)',
    },
    {
      'id': 'med_004',
      'brandName': 'Orsaline-N / SMC ORS',
      'genericName': 'Oral Rehydration Salts',
      'dosageForm': 'SACHET',
      'unit': 'Sachets',
      'stockUnits': 20,
      'threshold': 10,
      'rack': 'Rack C-1 (Electrolytes)',
    },
    {
      'id': 'med_005',
      'brandName': 'Povidone Iodine 10%',
      'genericName': 'Povidone Iodine Antiseptic Solution',
      'dosageForm': 'SOLUTION',
      'unit': 'Bottles / First Aid',
      'stockUnits': 20,
      'threshold': 5,
      'rack': 'First-Aid Rack (Dressing)',
    },
  ];

  // Dynamic stock multiplier control (Default: 1x, Options: 1x, 2x, 5x, 10x, 20x)
  int _selectedMultiplier = 1;
  final List<int> _multiplierOptions = [1, 2, 5, 10, 20];

  int _dispensedTodayCount = 0;
  String _searchQuery = '';
  bool _filterLowStockOnly = false;

  void _dispenseMedicine(int index) {
    final item = _inventory[index];
    final currentStock = item['stockUnits'] as int;

    if (currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text('${item['brandName']} is out of stock! Cannot dispense.'),
        ),
      );
      return;
    }

    final decrement = _selectedMultiplier;
    final actualDeduction = currentStock >= decrement ? decrement : currentStock;
    final newStock = currentStock - actualDeduction;

    setState(() {
      item['stockUnits'] = newStock;
      _dispensedTodayCount += actualDeduction;
    });

    _syncToFirestore(item['id'] as String, newStock);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: BaustColors.navyDark,
        content: Text(
          'Dispensed $actualDeduction unit(s) of ${item['brandName']} (${_selectedMultiplier}x). Remaining: $newStock',
        ),
      ),
    );
  }

  void _restockMedicine(int index) {
    final item = _inventory[index];
    final currentStock = item['stockUnits'] as int;
    final increment = _selectedMultiplier;
    final newStock = currentStock + increment;

    setState(() {
      item['stockUnits'] = newStock;
    });

    _syncToFirestore(item['id'] as String, newStock);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: BaustColors.successGreen,
        content: Text(
          'Restocked +$increment unit(s) of ${item['brandName']} (${_selectedMultiplier}x). Total: $newStock',
        ),
      ),
    );
  }

  Future<void> _syncToFirestore(String itemId, int newStock) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.inventory)
          .doc(itemId)
          .set({
        'stockUnits': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-blocking for offline or unit tests
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _inventory.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          (item['brandName'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item['genericName'] as String).toLowerCase().contains(_searchQuery.toLowerCase());

      final isLow = item['stockUnits'] < item['threshold'];
      final matchesLowFilter = !_filterLowStockOnly || isLow;

      return matchesSearch && matchesLowFilter;
    }).toList();

    final totalLowStock =
        _inventory.where((item) => item['stockUnits'] < item['threshold']).length;

    final Widget bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Summary Metrics
            Row(
              children: [
                _buildSummaryCard(
                  'Essential SKUs',
                  '${_inventory.length}',
                  BaustColors.primaryNavy,
                  Icons.medication,
                ),
                const SizedBox(width: 10),
                _buildSummaryCard(
                  'Low Stock',
                  '$totalLowStock Items',
                  totalLowStock > 0 ? BaustColors.emergencyRed : Colors.grey,
                  Icons.warning_amber_rounded,
                ),
                const SizedBox(width: 10),
                _buildSummaryCard(
                  'Dispensed Today',
                  '$_dispensedTodayCount Units',
                  BaustColors.successGreen,
                  Icons.outbox,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Patient Check-in Tracker Banner for Staff
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BaustColors.primaryArmyGreen.withValues(alpha: 0.3)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_ind, color: BaustColors.primaryArmyGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Check-In & Visit Log Tracker',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BaustColors.textDark),
                          ),
                          Text(
                            'Record and review student visits, arrivals & medicine dispensing logs.',
                            style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: BaustColors.primaryArmyGreen),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Multiplier Selector Card (Requirement 1: 1x, 2x, 5x, 10x, 20x)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, color: BaustColors.primaryNavy, size: 18),
                          const SizedBox(width: 6),
                          const Text(
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: BaustColors.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Step: ±$_selectedMultiplier unit${_selectedMultiplier > 1 ? "s" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: BaustColors.primaryNavy,
                          ),
                        ),
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? BaustColors.primaryNavy
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? BaustColors.primaryNavy
                                      : Colors.grey.shade300,
                                ),
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
            ),

            const SizedBox(height: 14),

            // Search & Filter Bar
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
                      hintText: 'Search top 5 core medicines...',
                      prefixIcon: const Icon(Icons.search, color: BaustColors.primaryNavy),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Show Low Stock Warnings Only',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
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

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOP 5 CORE MEDICINES (${filteredList.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: BaustColors.textMuted,
                  ),
                ),
                Text(
                  'Multiplier Active: ${_selectedMultiplier}x',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BaustColors.primaryNavy),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Inventory List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filteredList[index];
                final originalIndex = _inventory.indexOf(item);
                final stock = item['stockUnits'] as int;
                final threshold = item['threshold'] as int;
                final isLow = stock < threshold;

                return Card(
                  elevation: isLow ? 2 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isLow ? BaustColors.emergencyRed : Colors.grey.shade200,
                      width: isLow ? 1.5 : 1.0,
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
                              backgroundColor: isLow
                                  ? Colors.red.shade50
                                  : BaustColors.primaryNavy.withValues(alpha: 0.1),
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
                                  Text(
                                    item['brandName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'Generic: ${item['genericName']} • ${item['rack']}',
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
                              child: Text(
                                '$stock Units',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isLow ? BaustColors.emergencyRed : BaustColors.navyDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isLow) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.warning, size: 14, color: BaustColors.emergencyRed),
                              const SizedBox(width: 4),
                              Text(
                                'LOW STOCK WARNING (Below threshold of $threshold units)',
                                style: const TextStyle(
                                  color: BaustColors.emergencyRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 18),
                        Row(
                          children: [
                            Text(
                              'Form: ${item['dosageForm']} (${item['unit']})',
                              style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                            ),
                            const Spacer(),
                            // Action: Dispense (-) with Multiplier
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BaustColors.primaryNavy,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.remove, size: 14),
                              label: Text('-$_selectedMultiplier', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: stock > 0 ? () => _dispenseMedicine(originalIndex) : null,
                            ),
                            const SizedBox(width: 8),
                            // Action: Restock (+) with Multiplier
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: BaustColors.successGreen,
                                side: const BorderSide(color: BaustColors.successGreen),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 14),
                              label: Text('+$_selectedMultiplier', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _restockMedicine(originalIndex),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );

    if (!widget.showAppBar) {
      return Container(
        color: BaustColors.surfaceBg,
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      drawer: const SmartMediDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            final canPop = ModalRoute.of(context)?.canPop ?? false;
            if (canPop) {
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
              child: Image.asset(
                'assets/branding/smart_medi_icon_1024.png',
                height: 28,
                width: 28,
                fit: BoxFit.contain,
              ),
            ),
            const Flexible(
              child: Text(
                'Pharmacist Portal — Medicine Inventory',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Patient Check-in Log',
            icon: const Icon(Icons.assignment_ind_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Doctor Portal / Emergency Queue',
            icon: const Icon(Icons.medical_services_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: bodyContent,
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
            Text(
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
