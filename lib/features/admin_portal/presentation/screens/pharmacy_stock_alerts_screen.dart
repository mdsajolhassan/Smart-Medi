import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../medical_operations/data/models/inventory_item.dart';

/// Admin oversight of the pharmacy (read-only). Lists medicines that are low
/// on stock or expiring, how long they have gone without an update, and lets
/// the admin notify the pharmacist.
class PharmacyStockAlertsScreen extends ConsumerWidget {
  const PharmacyStockAlertsScreen({super.key});

  static Future<void> notifyPharmacist(
    WidgetRef ref, {
    required String type,
    required String message,
    String? itemId,
    String? medicineName,
  }) {
    final admin = ref.read(authControllerProvider).userProfile;
    return FirebaseFirestore.instance.collection(FirestoreCollections.pharmacyNotifications).add({
      'type': type,
      'message': message,
      'itemId': ?itemId,
      'medicineName': ?medicineName,
      'status': 'unread',
      'sentBy': admin?.email ?? 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gutter = Breakpoints.gutter(context);
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacy Stock Alerts')),
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection(FirestoreCollections.inventory).snapshots(),
          builder: (context, invSnap) {
            if (invSnap.hasError) return Center(child: Text('Could not load stock: ${invSnap.error}'));
            if (!invSnap.hasData) return const Center(child: CircularProgressIndicator());

            final alerts =
                invSnap.data!.docs
                    .map((d) => InventoryItem.fromMap(d.id, d.data()))
                    .where((i) => i.isLowStock || i.isExpired || i.isExpiringSoon)
                    .toList()
                  ..sort((a, b) => a.stockUnits.compareTo(b.stockUnits));

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection(FirestoreCollections.pharmacyNotifications)
                  .where('status', isEqualTo: 'unread')
                  .snapshots(),
              builder: (context, noticeSnap) {
                final pending = {
                  for (final d in noticeSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    (d.data()['itemId'] ?? '').toString(),
                };

                return ListView(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Text(
                        'The pharmacy is run by the pharmacist. Here you can see medicines that are low on stock '
                        'or expiring and remind the pharmacist to update them.',
                        style: TextStyle(fontSize: 12, color: BaustColors.primaryNavy),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (alerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'All medicines are in stock and in date.',
                            style: TextStyle(color: BaustColors.textMuted),
                          ),
                        ),
                      ),
                    for (var i = 0; i < alerts.length; i++)
                      FadeSlideIn(
                        index: i,
                        child: _AlertCard(item: alerts[i], alreadyNotified: pending.contains(alerts[i].id)),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final InventoryItem item;
  final bool alreadyNotified;
  const _AlertCard({required this.item, required this.alreadyNotified});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = item.updatedAt == null ? null : DateTime.now().difference(item.updatedAt!).inDays;
    final staleText = days == null
        ? 'Never updated'
        : (days == 0 ? 'Updated today' : 'Not updated for $days day${days == 1 ? '' : 's'}');

    final problems = [
      if (item.isLowStock) 'low stock (${item.stockUnits} left, minimum ${item.threshold})',
      if (item.isExpired) 'expired on ${InventoryItem.formatDate(item.expiryDate)}',
      if (item.isExpiringSoon) 'expires on ${InventoryItem.formatDate(item.expiryDate)}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.isExpired ? Icons.event_busy : Icons.warning_amber_rounded,
                  color: item.isExpired ? BaustColors.emergencyRed : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.brandName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text('${item.stockUnits} Units', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(problems.join(' • '), style: const TextStyle(fontSize: 12, color: BaustColors.emergencyRed)),
            Text(
              staleText,
              style: TextStyle(
                fontSize: 11,
                color: (days ?? 99) >= 3 ? Colors.orange.shade900 : BaustColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: alreadyNotified
                  ? const Chip(
                      avatar: Icon(Icons.mark_email_read_outlined, size: 16),
                      label: Text('Pharmacist notified', style: TextStyle(fontSize: 12)),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BaustColors.primaryNavy,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.notifications_active_outlined, size: 16),
                      label: const Text('Notify pharmacist'),
                      onPressed: () async {
                        try {
                          await PharmacyStockAlertsScreen.notifyPharmacist(
                            ref,
                            type: item.isLowStock ? 'low_stock' : 'expiry',
                            itemId: item.id,
                            medicineName: item.brandName,
                            message: 'Please update ${item.brandName}: ${problems.join(', ')}. ($staleText)',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: BaustColors.successGreen,
                                content: Text('Pharmacist notified about ${item.brandName}.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not notify: $e')));
                          }
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
