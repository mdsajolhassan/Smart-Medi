import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import 'pharmacy_stock_alerts_screen.dart';

/// Admin inbox for medicines that doctors prescribed but the pharmacy does not stock.
class CustomMedicineRequestsScreen extends ConsumerStatefulWidget {
  const CustomMedicineRequestsScreen({super.key});

  @override
  ConsumerState<CustomMedicineRequestsScreen> createState() => _CustomMedicineRequestsScreenState();
}

class _CustomMedicineRequestsScreenState extends ConsumerState<CustomMedicineRequestsScreen> {
  String _status = 'pending';

  late Stream<QuerySnapshot<Map<String, dynamic>>> _requests = _streamFor(_status);

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamFor(String status) => FirebaseFirestore.instance
      .collection(FirestoreCollections.customMedicineRequests)
      .where('status', isEqualTo: status)
      .snapshots();

  Future<void> _setStatus(String id, String status, {String? medicineName}) async {
    try {
      await FirebaseFirestore.instance.collection(FirestoreCollections.customMedicineRequests).doc(id).update({
        'status': status,
        'reviewedBy': ref.read(authControllerProvider).userProfile?.email ?? 'admin',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (status == 'forwarded' && medicineName != null && medicineName.trim().isNotEmpty) {
        await PharmacyStockAlertsScreen.notifyPharmacist(
          ref,
          type: 'custom_medicine',
          medicineName: medicineName.trim(),
          message:
              'Doctors are prescribing "${medicineName.trim()}", which is not in stock. Please consider adding it.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = Breakpoints.gutter(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Medicine Requests')),
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', icon: Icon(Icons.inbox_rounded), label: Text('Pending')),
                  ButtonSegment(
                    value: 'forwarded',
                    icon: Icon(Icons.forward_to_inbox_outlined),
                    label: Text('Forwarded'),
                  ),
                  ButtonSegment(value: 'dismissed', icon: Icon(Icons.block), label: Text('Dismissed')),
                ],
                selected: {_status},
                onSelectionChanged: (s) => setState(() {
                  _status = s.first;
                  _requests = _streamFor(_status);
                }),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _requests,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Could not load requests: ${snap.error}'));
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snap.data!.docs.toList()
                    ..sort((a, b) {
                      final at = a.data()['createdAt'];
                      final bt = b.data()['createdAt'];
                      if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
                      return 0;
                    });

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No requests here.', style: TextStyle(color: BaustColors.textMuted)),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 24),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final ts = d['createdAt'];
                      final when = ts is Timestamp
                          ? '${ts.toDate().day.toString().padLeft(2, '0')}/${ts.toDate().month.toString().padLeft(2, '0')}/${ts.toDate().year}'
                          : '';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.medication_outlined, color: BaustColors.primaryArmyGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (d['medicineName'] ?? '').toString(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  if (when.isNotEmpty)
                                    Text(when, style: const TextStyle(fontSize: 11, color: BaustColors.textMuted)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Prescribed by ${d['doctorName'] ?? 'Doctor'} for student ${d['studentId'] ?? '-'}',
                                style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                              ),
                              if (_status == 'pending') ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: BaustColors.successGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.forward_to_inbox_outlined, size: 16),
                                      label: const Text('Forward to pharmacist'),
                                      onPressed: () => _setStatus(
                                        docs[i].id,
                                        'forwarded',
                                        medicineName: (d['medicineName'] ?? '').toString(),
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _setStatus(docs[i].id, 'dismissed'),
                                      child: const Text('Dismiss'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
