import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../medical_onboarding_ai/presentation/screens/medical_onboarding_screen.dart';
import '../../../medical_operations/data/models/prescription_model.dart';
import '../../../medical_operations/data/services/prescription_pdf_service.dart';
import 'detailed_medical_history_screen.dart';

class MedicalHistoryTabScreen extends ConsumerWidget {
  final bool showAppBar;

  const MedicalHistoryTabScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;

    if (user == null) {
      return const Center(child: CircularProgressIndicator(color: BaustColors.primaryArmyGreen));
    }

    Stream<DocumentSnapshot<Map<String, dynamic>>>? historyStream;
    Stream<List<PrescriptionModel>>? prescriptionsStream;

    try {
      historyStream = FirebaseFirestore.instance
          .collection('medical_histories')
          .doc(user.uid)
          .snapshots();
    } catch (_) {
      historyStream = null;
    }

    try {
      prescriptionsStream = FirebaseFirestore.instance
          .collection('prescriptions')
          .where('studentUid', isEqualTo: user.uid)
          .snapshots()
          .map((snap) {
            final list = snap.docs.map((doc) => PrescriptionModel.fromSnapshot(doc)).toList();
            list.sort((a, b) {
              final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });
            return list;
          });
    } catch (_) {
      prescriptionsStream = null;
    }

    final content = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: BaustColors.primaryArmyGreen),
          );
        }

        final data = snapshot.data?.data();

        if (prescriptionsStream == null) {
          return _buildContent(context, user, data, const []);
        }

        return StreamBuilder<List<PrescriptionModel>>(
          stream: prescriptionsStream,
          builder: (context, rxSnapshot) {
            final rxList = rxSnapshot.data ?? const [];
            return _buildContent(context, user, data, rxList);
          },
        );
      },
    );

    if (showAppBar) {
      return Scaffold(
        backgroundColor: BaustColors.surfaceBg,
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
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/branding/smart_medi_icon_1024.png',
                  height: 32,
                  width: 32,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) {
                  final canPop = ModalRoute.of(context)?.canPop ?? false;
                  if (!canPop) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.asset(
                      'assets/branding/smart_medi_icon_1024.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
              const Flexible(
                child: Text(
                  'AI Medical Summary',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildContent(
    BuildContext context,
    UserProfile user,
    Map<String, dynamic>? data,
    List<PrescriptionModel> rxList,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [BaustColors.armyGreenDark, BaustColors.primaryArmyGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child: Image.asset(
                    'assets/branding/smart_medi_icon_1024.png',
                    height: 32,
                    width: 32,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Medical Record',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Multimodal clinical extraction powered by Gemini',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Digital Prescriptions Issued by BAUST Medical Center
          if (rxList.isNotEmpty) ...[
            _buildIssuedPrescriptionsSection(context, user, rxList),
            const SizedBox(height: 16),
          ],

          if (data == null || data.isEmpty) ...[
                // Empty state card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BaustColors.primaryArmyGreen.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.note_alt_outlined,
                          size: 40,
                          color: BaustColors.primaryArmyGreen,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No Medical Summary Recorded',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BaustColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Upload a doctor prescription, clinical record, or lab report to extract and store your critical medical profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BaustColors.primaryNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.history_edu),
                        label: const Text('View Detailed Medical History'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DetailedMedicalHistoryScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BaustColors.primaryArmyGreen,
                          side: const BorderSide(color: BaustColors.primaryArmyGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.document_scanner),
                        label: const Text('Start AI Medical Onboarding'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MedicalOnboardingScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Clinical Summary Card
                _buildSectionCard(
                  title: 'CLINICAL SUMMARY',
                  icon: Icons.summarize_outlined,
                  color: BaustColors.primaryArmyGreen,
                  child: Text(
                    (data['clinicalSummary'] ?? 'No summary available').toString(),
                    style: const TextStyle(fontSize: 13, height: 1.4, color: BaustColors.textDark),
                  ),
                ),

                const SizedBox(height: 14),

                // Blood Group Source Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          (data['bloodGroup'] ?? 'N/A').toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: BaustColors.emergencyRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Source: ${(data['bloodGroupSource'] ?? "Unspecified").toString()}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BaustColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data['bloodGroupVerified'] == true
                                  ? 'Verified by Medical Officer'
                                  : 'Unverified (Clinical AI extraction)',
                              style: TextStyle(
                                fontSize: 11,
                                color: data['bloodGroupVerified'] == true ? BaustColors.successGreen : Colors.amber.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Known Allergies
                _buildListSection(
                  title: 'KNOWN ALLERGIES (CRITICAL FLAGS)',
                  icon: Icons.warning_amber_rounded,
                  iconColor: BaustColors.emergencyRed,
                  items: List<String>.from(data['knownAllergies'] ?? []),
                  emptyText: 'No allergies recorded in document.',
                ),

                const SizedBox(height: 14),

                // Chronic Conditions
                _buildListSection(
                  title: 'CHRONIC CONDITIONS & DIAGNOSES',
                  icon: Icons.healing_outlined,
                  iconColor: Colors.blue.shade700,
                  items: List<String>.from(data['historicalProblems'] ?? []),
                  emptyText: 'No chronic conditions reported.',
                ),

                const SizedBox(height: 14),

                // Active Medications
                _buildListSection(
                  title: 'CURRENT & ONGOING MEDICATIONS',
                  icon: Icons.medication_outlined,
                  iconColor: BaustColors.primaryArmyGreen,
                  items: List<String>.from(data['activeIssues'] ?? []),
                  emptyText: 'No active medications found in document.',
                ),

                const SizedBox(height: 20),

                // Prominent Detailed Medical History Button (Task 1)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BaustColors.primaryNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.history_edu, size: 20),
                  label: const Text(
                    'View Detailed Medical History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.6),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailedMedicalHistoryScreen(initialData: data),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Upload New Document Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BaustColors.primaryArmyGreen,
                    side: const BorderSide(color: BaustColors.primaryArmyGreen),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text(
                    'UPLOAD NEW MEDICAL DOCUMENT',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MedicalOnboardingScreen()),
                    );
                  },
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: BaustColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildListSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> items,
    required String emptyText,
  }) {
    return _buildSectionCard(
      title: title,
      icon: icon,
      color: iconColor,
      child: items.isEmpty
          ? Text(
              emptyText,
              style: const TextStyle(fontSize: 12, color: BaustColors.textMuted, fontStyle: FontStyle.italic),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildIssuedPrescriptionsSection(
    BuildContext context,
    UserProfile user,
    List<PrescriptionModel> rxList,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication, size: 18, color: BaustColors.primaryArmyGreen),
              const SizedBox(width: 8),
              Text(
                'ISSUED PRESCRIPTIONS (${rxList.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: BaustColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final rx in rxList)
            _buildPrescriptionCard(context, user, rx),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(BuildContext context, UserProfile user, PrescriptionModel rx) {
    final dateStr = rx.createdAt != null
        ? '${rx.createdAt!.day.toString().padLeft(2, '0')}/${rx.createdAt!.month.toString().padLeft(2, '0')}/${rx.createdAt!.year}'
        : 'Recent';

    final enrichedRx = PrescriptionModel(
      id: rx.id,
      studentUid: rx.studentUid,
      studentId: rx.studentId,
      studentName: rx.studentName,
      doctorUid: rx.doctorUid,
      doctorName: rx.doctorName,
      doctorDesignation: rx.doctorDesignation,
      diagnosis: rx.diagnosis,
      items: rx.items,
      advice: rx.advice,
      followUpDate: rx.followUpDate,
      source: rx.source,
      createdAt: rx.createdAt,
      studentDepartment: user.department,
      studentBloodGroup: user.bloodGroup,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  rx.diagnosis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BaustColors.primaryNavy),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rx.source == 'scan'
                ? 'Issued by BAUST Medical Center - ${rx.doctorName.trim().startsWith('Dr.') ? rx.doctorName.trim() : 'Dr. ${rx.doctorName.trim()}'} (digitized from paper)'
                : 'Issued by BAUST Medical Center - ${rx.doctorName.trim().startsWith('Dr.') ? rx.doctorName.trim() : 'Dr. ${rx.doctorName.trim()}'}',
            style: const TextStyle(fontSize: 11, color: BaustColors.primaryArmyGreen, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Medicines:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.textDark),
          ),
          const SizedBox(height: 2),
          for (final item in rx.items)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                '• ${item.name} — ${item.dose}, ${item.frequency}, ${item.duration}${item.instructions != null && item.instructions!.isNotEmpty ? " (${item.instructions})" : ""}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
              ),
            ),
          if (rx.advice != null && rx.advice!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Advice: ${rx.advice!.trim()}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic),
            ),
          ],
          if (rx.followUpDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Follow-up: ${rx.followUpDate!.day}/${rx.followUpDate!.month}/${rx.followUpDate!.year}',
              style: const TextStyle(fontSize: 11, color: BaustColors.primaryNavy, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: BaustColors.primaryNavy,
                side: const BorderSide(color: BaustColors.primaryNavy),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.print_outlined, size: 14),
              label: const Text('Print / Save PDF', style: TextStyle(fontSize: 11)),
              onPressed: () => PrescriptionPdfService.printOrShare(enrichedRx),
            ),
          ),
        ],
      ),
    );
  }
}
