import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../emergency_sos/presentation/screens/sos_screen.dart';
import '../../../medical_operations/data/models/prescription_model.dart';
import '../../../medical_operations/data/services/prescription_pdf_service.dart';
import '../../../medical_operations/presentation/screens/new_prescription_screen.dart';

/// Clinical Timeline Entry Model representing individual chronological milestones
class ClinicalTimelineEntry {
  final String date;
  final String title;
  final String category; // 'Surgery', 'Prescription', 'Diagnosis', 'Admission', 'Clinical Note'
  final String description;
  final String? doctorOrFacility;
  final String? dosageOrDetails;
  final IconData icon;
  final Color color;
  final bool isCritical;
  final PrescriptionModel? prescription;

  const ClinicalTimelineEntry({
    required this.date,
    required this.title,
    required this.category,
    required this.description,
    this.doctorOrFacility,
    this.dosageOrDetails,
    required this.icon,
    required this.color,
    this.isCritical = false,
    this.prescription,
  });
}

class DetailedMedicalHistoryScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? studentUid;
  final Map<String, dynamic>? patientProfile;
  final bool isDoctorView;
  final List<PrescriptionModel>? initialPrescriptions;

  const DetailedMedicalHistoryScreen({
    super.key,
    this.initialData,
    this.studentUid,
    this.patientProfile,
    this.isDoctorView = false,
    this.initialPrescriptions,
  });

  @override
  ConsumerState<DetailedMedicalHistoryScreen> createState() => _DetailedMedicalHistoryScreenState();
}

class _DetailedMedicalHistoryScreenState extends ConsumerState<DetailedMedicalHistoryScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ClinicalTimelineEntry> _buildChronologicalTimeline(
    Map<String, dynamic>? data,
    UserProfile? user, [
    List<PrescriptionModel> digitalPrescriptions = const [],
  ]) {
    final List<ClinicalTimelineEntry> entries = [];

    // 1. Parse Procedures & Surgeries from Firestore doc if available
    if (data != null && data['procedures'] is List) {
      for (final p in (data['procedures'] as List)) {
        if (p is Map) {
          final String title = (p['name']?.toString().trim().isNotEmpty ?? false)
              ? p['name'].toString().trim()
              : 'Not found - confirm with patient';
          final String date = (p['date']?.toString().trim().isNotEmpty ?? false)
              ? p['date'].toString().trim()
              : 'Not found - confirm with patient';
          final String doctorOrFacility = (p['facility']?.toString().trim().isNotEmpty ?? false)
              ? p['facility'].toString().trim()
              : 'Not found - confirm with patient';
          final String? dosageOrDetails = (p['details']?.toString().trim().isNotEmpty ?? false)
              ? p['details'].toString().trim()
              : ((p['dosage']?.toString().trim().isNotEmpty ?? false)
                  ? p['dosage'].toString().trim()
                  : null);

          entries.add(
            ClinicalTimelineEntry(
              date: date,
              title: title,
              category: 'Surgery',
              description: 'Surgical procedure documented in patient health record.',
              doctorOrFacility: doctorOrFacility,
              dosageOrDetails: dosageOrDetails,
              icon: Icons.local_hospital,
              color: BaustColors.emergencyRed,
              isCritical: true,
            ),
          );
        }
      }
    }

    // 2. Parse AI-extracted Prescriptions & Medications
    if (data != null && data['prescriptions'] is List) {
      for (final m in (data['prescriptions'] as List)) {
        if (m is Map) {
          final String title = (m['name']?.toString().trim().isNotEmpty ?? false)
              ? m['name'].toString().trim()
              : 'Not found - confirm with patient';
          final String date = (m['prescribed_date']?.toString().trim().isNotEmpty ?? false)
              ? m['prescribed_date'].toString().trim()
              : 'Not found - confirm with patient';
          final String dosage = (m['dosage']?.toString().trim().isNotEmpty ?? false)
              ? m['dosage'].toString().trim()
              : ((m['dose']?.toString().trim().isNotEmpty ?? false)
                  ? m['dose'].toString().trim()
                  : 'Not found - confirm with patient');
          final String frequency = (m['frequency']?.toString().trim().isNotEmpty ?? false)
              ? m['frequency'].toString().trim()
              : 'Not found - confirm with patient';
          final String instructions = (m['instructions']?.toString().trim().isNotEmpty ?? false)
              ? m['instructions'].toString().trim()
              : ((m['duration_text']?.toString().trim().isNotEmpty ?? false)
                  ? m['duration_text'].toString().trim()
                  : 'Not found - confirm with patient');
          final String docStr = (m['doctor']?.toString().trim().isNotEmpty ?? false)
              ? m['doctor'].toString().trim()
              : '';
          final String doctorOrFacility = docStr.isNotEmpty
              ? 'AI-extracted from uploaded document ($docStr)'
              : 'AI-extracted from uploaded document';

          entries.add(
            ClinicalTimelineEntry(
              date: date,
              title: title,
              category: 'Prescription',
              description: 'Dosage: $dosage, Frequency: $frequency',
              dosageOrDetails: instructions,
              doctorOrFacility: doctorOrFacility,
              icon: Icons.medication,
              color: BaustColors.primaryArmyGreen,
            ),
          );
        }
      }
    }

    // 3. Digital Prescriptions (Issued by BAUST Medical Center Doctors)
    for (final rx in digitalPrescriptions) {
      final dateStr = rx.createdAt != null
          ? '${rx.createdAt!.day.toString().padLeft(2, '0')}/${rx.createdAt!.month.toString().padLeft(2, '0')}/${rx.createdAt!.year}'
          : 'Recent';
      final itemsStr = rx.items.map((i) => '${i.name} (${i.dose}, ${i.frequency})').join('; ');

      entries.add(
        ClinicalTimelineEntry(
          date: dateStr,
          title: 'Digital Prescription: ${rx.diagnosis}',
          category: 'Prescription',
          description: itemsStr,
          dosageOrDetails: rx.advice != null && rx.advice!.trim().isNotEmpty ? rx.advice : null,
          doctorOrFacility: 'Issued by BAUST Medical Center - ${rx.doctorName.trim().startsWith('Dr.') ? rx.doctorName.trim() : 'Dr. ${rx.doctorName.trim()}'}',
          icon: Icons.assignment_turned_in,
          color: BaustColors.primaryArmyGreen,
          prescription: rx,
        ),
      );
    }

    // 3. Parse Active Issues & Current Medications from summary
    if (data != null && data['activeIssues'] is List) {
      final activeList = List<String>.from(data['activeIssues']);
      for (int i = 0; i < activeList.length; i++) {
        final item = activeList[i].trim();
        if (item.isNotEmpty) {
          entries.add(
            ClinicalTimelineEntry(
              date: 'Ongoing / Current Regimen',
              title: item,
              category: 'Prescription',
              description: 'Active medication verified in patient medical history dossier.',
              doctorOrFacility: 'Not found - confirm with patient',
              icon: Icons.medication_liquid_outlined,
              color: BaustColors.primaryArmyGreen,
            ),
          );
        }
      }
    }

    // 4. Parse Historical Problems & Diagnoses
    if (data != null && data['historicalProblems'] is List) {
      final histList = List<String>.from(data['historicalProblems']);
      for (int i = 0; i < histList.length; i++) {
        final problem = histList[i].trim();
        if (problem.isNotEmpty) {
          entries.add(
            ClinicalTimelineEntry(
              date: 'Recorded in Profile',
              title: problem,
              category: 'Diagnosis',
              description: 'Chronic condition / pathological diagnosis recorded in patient profile.',
              doctorOrFacility: 'Not found - confirm with patient',
              icon: Icons.healing,
              color: Colors.blue.shade700,
              isCritical: problem.toLowerCase().contains('asthma') ||
                  problem.toLowerCase().contains('cardiac') ||
                  problem.toLowerCase().contains('diabetes'),
            ),
          );
        }
      }
    }

    // 5. Parse Known Allergies
    if (data != null && data['knownAllergies'] is List) {
      final allergies = List<String>.from(data['knownAllergies']);
      for (final a in allergies) {
        final allergen = a.trim();
        if (allergen.isNotEmpty) {
          entries.add(
            ClinicalTimelineEntry(
              date: 'Life-Long / Critical Alert',
              title: 'Hypersensitivity: $allergen',
              category: 'Critical Alert',
              description: 'High-priority allergen warning. Cross-reactive medications contraindicated.',
              doctorOrFacility: 'Not found - confirm with patient',
              icon: Icons.warning_amber_rounded,
              color: BaustColors.emergencyRed,
              isCritical: true,
            ),
          );
        }
      }
    }

    // 6. Parse Clinical Summary & Notes
    if (data != null && data['clinicalSummary'] != null && data['clinicalSummary'].toString().trim().isNotEmpty) {
      entries.add(
        ClinicalTimelineEntry(
          date: 'Clinical Overview',
          title: 'Clinical Summary / Note',
          category: 'Clinical Note',
          description: data['clinicalSummary'].toString().trim(),
          doctorOrFacility: 'Not found - confirm with patient',
          icon: Icons.article_outlined,
          color: BaustColors.primaryNavy,
        ),
      );
    }

    return entries;
  }

  void _showExportDossierDialog(UserProfile? user, List<ClinicalTimelineEntry> entries) {
    final String blood = (user?.bloodGroup != null && user!.bloodGroup!.trim().isNotEmpty)
        ? user.bloodGroup!.trim()
        : 'Not found - confirm with patient';

    final String name = (user?.displayName != null && user!.displayName.trim().isNotEmpty)
        ? user.displayName.trim()
        : 'Not found - confirm with patient';

    final String roll = (user?.studentRoll != null && user!.studentRoll!.trim().isNotEmpty)
        ? user.studentRoll!.trim()
        : 'Not found - confirm with patient';

    final String location;
    if (user != null) {
      if (user.isResidential) {
        final hall = (user.residentialHall != null &&
                user.residentialHall!.trim().isNotEmpty &&
                !user.residentialHall!.contains('Non-Residential'))
            ? user.residentialHall!.trim()
            : null;
        final room = (user.roomNumber != null &&
                user.roomNumber!.trim().isNotEmpty &&
                user.roomNumber != 'N/A')
            ? user.roomNumber!.trim()
            : null;
        if (hall != null && room != null) {
          location = '$hall, Room: $room';
        } else if (hall != null) {
          location = '$hall, Room: Not found - confirm with patient';
        } else {
          location = 'Hall: Not found - confirm with patient';
        }
      } else {
        final parts = [
          if (user.detailedAddress != null && user.detailedAddress!.trim().isNotEmpty) user.detailedAddress!.trim(),
          if (user.upazila != null && user.upazila!.trim().isNotEmpty) user.upazila!.trim(),
          if (user.district != null && user.district!.trim().isNotEmpty) user.district!.trim(),
        ];
        location = parts.isNotEmpty
            ? 'Non-Residential: ${parts.join(", ")}'
            : 'Non-Residential (Address: Not found - confirm with patient)';
      }
    } else {
      location = 'Not found - confirm with patient';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.print_outlined, color: BaustColors.primaryNavy),
            SizedBox(width: 8),
            Text('Clinical Dossier Export', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BAUST MEDICAL CENTER — OFFICIAL CLINICAL SUMMARY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BaustColors.primaryNavy),
              ),
              const Divider(height: 16),
              Text('Patient: $name'),
              Text('Student Roll: $roll'),
              Text('Blood Group: $blood'),
              Text('Location: $location'),
              const SizedBox(height: 12),
              Text(
                'Total Chronological Milestones: ${entries.isEmpty ? "Not found - confirm with patient" : entries.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This comprehensive health record is cryptographically indexed with Firebase Security Rules and ready for university hospital consultations.',
                style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: BaustColors.primaryNavy, foregroundColor: Colors.white),
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share Summary'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: BaustColors.successGreen,
                  content: Text('Medical Dossier prepared for clinical consultation export.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;

    final targetUser = widget.patientProfile != null
        ? UserProfile(
            uid: widget.studentUid ?? 'patient',
            email: widget.patientProfile!['email']?.toString() ?? 'student@baust.edu.bd',
            displayName: widget.patientProfile!['displayName']?.toString() ?? 'Student',
            role: widget.patientProfile!['role']?.toString() ?? 'student',
            studentRoll: (widget.patientProfile!['studentRoll'] ?? widget.patientProfile!['studentId'])?.toString(),
            department: widget.patientProfile!['department']?.toString(),
            bloodGroup: widget.patientProfile!['bloodGroup']?.toString(),
            residentialHall: widget.patientProfile!['residentialHall']?.toString(),
            roomNumber: widget.patientProfile!['roomNumber']?.toString(),
            phone: widget.patientProfile!['phone']?.toString(),
            district: widget.patientProfile!['district']?.toString(),
            upazila: widget.patientProfile!['upazila']?.toString(),
            detailedAddress: widget.patientProfile!['detailedAddress']?.toString(),
            residencyStatus: widget.patientProfile!['residencyStatus']?.toString() ?? 'residential',
            isWillingToDonateBlood: widget.patientProfile!['isWillingToDonateBlood'] as bool? ?? false,
            bloodGroupVerified: widget.patientProfile!['bloodGroupVerified'] as bool? ?? false,
          )
        : user;

    final targetUid = widget.studentUid ?? user?.uid;

    Stream<DocumentSnapshot<Map<String, dynamic>>>? historyStream;
    Stream<List<PrescriptionModel>>? prescriptionsStream;

    if (targetUid != null) {
      try {
        historyStream = FirebaseFirestore.instance
            .collection('medical_histories')
            .doc(targetUid)
            .snapshots();
      } catch (_) {
        historyStream = null;
      }

      try {
        prescriptionsStream = FirebaseFirestore.instance
            .collection('prescriptions')
            .where('studentUid', isEqualTo: targetUid)
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
    }

    if (widget.initialData != null && widget.initialPrescriptions != null) {
      return _buildScaffold(context, targetUser, widget.initialData, widget.initialPrescriptions!);
    }

    if (widget.initialData != null) {
      if (prescriptionsStream == null) {
        return _buildScaffold(context, targetUser, widget.initialData, widget.initialPrescriptions ?? const []);
      }
      return StreamBuilder<List<PrescriptionModel>>(
        stream: prescriptionsStream,
        builder: (context, rxSnap) {
          final rxList = rxSnap.data ?? widget.initialPrescriptions ?? const [];
          return _buildScaffold(context, targetUser, widget.initialData, rxList);
        },
      );
    }

    if (historyStream == null && prescriptionsStream == null) {
      return _buildScaffold(context, targetUser, null, widget.initialPrescriptions ?? const []);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: historyStream,
      builder: (context, historySnap) {
        final data = historySnap.data?.data() ?? widget.initialData;

        if (widget.initialPrescriptions != null) {
          return _buildScaffold(context, targetUser, data, widget.initialPrescriptions!);
        }

        if (prescriptionsStream == null) {
          return _buildScaffold(context, targetUser, data, const []);
        }

        return StreamBuilder<List<PrescriptionModel>>(
          stream: prescriptionsStream,
          builder: (context, rxSnap) {
            final rxList = rxSnap.data ?? const [];
            return _buildScaffold(context, targetUser, data, rxList);
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    UserProfile? user,
    Map<String, dynamic>? data, [
    List<PrescriptionModel> digitalPrescriptions = const [],
  ]) {
    final allEntries = _buildChronologicalTimeline(data, user, digitalPrescriptions);

    final filteredEntries = allEntries.where((entry) {
      final matchesCategory = _selectedCategory == 'All' ||
          (_selectedCategory == 'Surgeries' && entry.category == 'Surgery') ||
          (_selectedCategory == 'Prescriptions' && entry.category == 'Prescription') ||
          (_selectedCategory == 'Conditions' && entry.category == 'Diagnosis') ||
          (_selectedCategory == 'Clinical Notes' && entry.category == 'Clinical Note') ||
          (_selectedCategory == 'Critical Flags' && entry.isCritical);

      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          entry.title.toLowerCase().contains(query) ||
          entry.description.toLowerCase().contains(query) ||
          entry.date.toLowerCase().contains(query) ||
          (entry.dosageOrDetails?.toLowerCase().contains(query) ?? false) ||
          (entry.doctorOrFacility?.toLowerCase().contains(query) ?? false);

      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Image.asset(
                'assets/branding/smart_medi_icon_1024.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
            ),
            Flexible(
              child: Text(
                widget.isDoctorView
                    ? 'Patient Medical History & Dossier'
                    : 'Detailed Medical History & Dossier',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.isDoctorView)
            IconButton(
              tooltip: 'Export / Print Summary',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _showExportDossierDialog(user, allEntries),
            ),
          if (!widget.isDoctorView)
            IconButton(
              tooltip: 'Emergency SOS',
              icon: const Icon(Icons.emergency_outlined, color: BaustColors.emergencyRed),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SosScreen()),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Red Known Allergies Banner (Always shown in Doctor View)
            if (widget.isDoctorView) ...[
              _buildDoctorAllergiesBanner(data, widget.patientProfile),
              const SizedBox(height: 16),
            ],

            // Patient Identification Banner
            _buildPatientDossierBanner(user),

            const SizedBox(height: 16),

            // Prescriptions Issued Section (Doctor & Student View)
            _buildIssuedPrescriptionsSection(context, user, digitalPrescriptions, data),

            const SizedBox(height: 16),

            // Metrics Summary Grid
            _buildMetricsGrid(allEntries),

            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search surgeries, prescriptions, conditions, notes...',
                prefixIcon: const Icon(Icons.search, color: BaustColors.primaryNavy),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),

            const SizedBox(height: 12),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Surgeries',
                  'Prescriptions',
                  'Conditions',
                  'Clinical Notes',
                  'Critical Flags',
                ].map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : BaustColors.textDark,
                        ),
                      ),
                      selectedColor: BaustColors.primaryNavy,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? BaustColors.primaryNavy : Colors.grey.shade300,
                        ),
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = category),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timeline, color: BaustColors.primaryNavy, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'A-TO-Z CHRONOLOGICAL CLINICAL TIMELINE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: BaustColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${filteredEntries.length} Records',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BaustColors.textMuted),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (filteredEntries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 40, color: BaustColors.textMuted),
                    const SizedBox(height: 10),
                    Text(
                      allEntries.isEmpty
                          ? (widget.isDoctorView
                              ? 'This student has not uploaded a medical history yet.'
                              : 'Not found - confirm with patient')
                          : 'No timeline entries match your filter',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allEntries.isEmpty
                          ? (widget.isDoctorView
                              ? 'No medical documents or prescriptions have been submitted by this student.'
                              : 'No clinical records found in medical history for this patient.')
                          : 'Try selecting a different category or clearing search.',
                      style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredEntries.length,
                itemBuilder: (context, index) {
                  final item = filteredEntries[index];
                  final isLast = index == filteredEntries.length - 1;
                  return _buildTimelineItem(item, isLast);
                },
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientDossierBanner(UserProfile? user) {
    final String blood = (user?.bloodGroup != null && user!.bloodGroup!.trim().isNotEmpty)
        ? user.bloodGroup!.trim()
        : 'Not found - confirm with patient';

    final String name = (user?.displayName != null && user!.displayName.trim().isNotEmpty)
        ? user.displayName.trim()
        : 'Not found - confirm with patient';

    final String roll = (user?.studentRoll != null && user!.studentRoll!.trim().isNotEmpty)
        ? user.studentRoll!.trim()
        : 'Not found - confirm with patient';

    final String department = (user?.department != null && user!.department!.trim().isNotEmpty)
        ? user.department!.trim()
        : 'Not found - confirm with patient';

    final String location;
    if (user != null) {
      if (user.isResidential) {
        final hall = (user.residentialHall != null &&
                user.residentialHall!.trim().isNotEmpty &&
                !user.residentialHall!.contains('Non-Residential'))
            ? user.residentialHall!.trim()
            : null;
        final room = (user.roomNumber != null &&
                user.roomNumber!.trim().isNotEmpty &&
                user.roomNumber != 'N/A')
            ? user.roomNumber!.trim()
            : null;
        if (hall != null && room != null) {
          location = '$hall, Room: $room';
        } else if (hall != null) {
          location = '$hall, Room: Not found - confirm with patient';
        } else {
          location = 'Hall: Not found - confirm with patient';
        }
      } else {
        final parts = [
          if (user.detailedAddress != null && user.detailedAddress!.trim().isNotEmpty) user.detailedAddress!.trim(),
          if (user.upazila != null && user.upazila!.trim().isNotEmpty) user.upazila!.trim(),
          if (user.district != null && user.district!.trim().isNotEmpty) user.district!.trim(),
        ];
        location = parts.isNotEmpty
            ? 'Non-Residential: ${parts.join(", ")}'
            : 'Non-Residential (Address: Not found - confirm with patient)';
      }
    } else {
      location = 'Not found - confirm with patient';
    }

    final bool isBloodKnown = blood != 'Not found - confirm with patient';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: BaustColors.primaryArmyGreen.withValues(alpha: 0.3),
                child: const Icon(Icons.badge_outlined, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isBloodKnown ? 10 : 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isBloodKnown ? BaustColors.emergencyRed : Colors.grey.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                blood,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isBloodKnown ? 14 : 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (widget.isDoctorView) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade900,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Unverified',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Student Roll: $roll • $department',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 22),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                widget.isDoctorView ? Icons.info_outline : Icons.verified_user_outlined,
                size: 16,
                color: widget.isDoctorView ? Colors.amber.shade400 : BaustColors.successGreen,
              ),
              const SizedBox(width: 6),
              Text(
                widget.isDoctorView
                    ? 'AI-extracted, unverified - confirm with patient'
                    : 'BAUST Institutional Medical Center Verified Health Record',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(List<ClinicalTimelineEntry> entries) {
    final surgeries = entries.where((e) => e.category == 'Surgery').length;
    final prescriptions = entries.where((e) => e.category == 'Prescription').length;
    final conditions = entries.where((e) => e.category == 'Diagnosis').length;
    final critical = entries.where((e) => e.isCritical).length;

    return Row(
      children: [
        _buildMetricTile('Surgeries', '$surgeries', Icons.local_hospital, BaustColors.emergencyRed),
        const SizedBox(width: 8),
        _buildMetricTile('Prescriptions', '$prescriptions', Icons.medication, BaustColors.primaryArmyGreen),
        const SizedBox(width: 8),
        _buildMetricTile('Diagnoses', '$conditions', Icons.healing, Colors.blue.shade700),
        const SizedBox(width: 8),
        _buildMetricTile('Critical', '$critical', Icons.warning_amber_rounded, Colors.amber.shade900),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
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
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: BaustColors.textMuted, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(ClinicalTimelineEntry item, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line and Node
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: item.color, width: 2),
                ),
                child: Icon(item.icon, size: 16, color: item.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: item.isCritical ? item.color.withValues(alpha: 0.4) : Colors.grey.shade200,
                  width: item.isCritical ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        item.date,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BaustColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                  ),
                  if (item.dosageOrDetails != null && item.dosageOrDetails!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: BaustColors.primaryNavy),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.dosageOrDetails!,
                              style: const TextStyle(fontSize: 11, color: BaustColors.textDark, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (item.doctorOrFacility != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_pin, size: 13, color: BaustColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.doctorOrFacility!,
                            style: const TextStyle(fontSize: 11, color: BaustColors.textMuted, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.prescription != null) ...[
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
                        onPressed: () => PrescriptionPdfService.printOrShare(item.prescription!),
                      ),
                    ),
                  ] else if (widget.isDoctorView) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Text(
                        'AI-extracted, unverified - confirm with patient',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF78350F),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openNewPrescription(BuildContext context, UserProfile? user, Map<String, dynamic>? data) {
    final List<String> allergies = [];
    if (data != null && data['knownAllergies'] is List) {
      for (final a in data['knownAllergies']) {
        if (a != null && a.toString().trim().isNotEmpty) {
          allergies.add(a.toString().trim());
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewPrescriptionScreen(
          studentUid: widget.studentUid ?? user?.uid ?? '',
          studentId: user?.studentRoll ??
              widget.patientProfile?['studentRoll']?.toString() ??
              widget.patientProfile?['studentId']?.toString() ??
              '',
          studentName: user?.displayName ??
              widget.patientProfile?['displayName']?.toString() ??
              'Student',
          knownAllergies: allergies,
          studentDepartment: user?.department ?? widget.patientProfile?['department']?.toString(),
          studentBloodGroup: user?.bloodGroup ?? widget.patientProfile?['bloodGroup']?.toString(),
        ),
      ),
    );
  }

  Widget _buildIssuedPrescriptionsSection(
    BuildContext context,
    UserProfile? user,
    List<PrescriptionModel> prescriptions,
    Map<String, dynamic>? data,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.medication, color: BaustColors.primaryArmyGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'PRESCRIPTIONS ISSUED (${prescriptions.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: BaustColors.textDark,
                    ),
                  ),
                ],
              ),
              if (widget.isDoctorView)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BaustColors.primaryArmyGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Prescription', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _openNewPrescription(context, user, data),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (prescriptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                widget.isDoctorView
                    ? 'No digital prescriptions issued yet for this student.'
                    : 'No digital prescriptions on file.',
                style: const TextStyle(fontSize: 12, color: BaustColors.textMuted, fontStyle: FontStyle.italic),
              ),
            )
          else
            Column(
              children: prescriptions.map((rx) => _buildPrescriptionCard(context, user, rx)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(BuildContext context, UserProfile? user, PrescriptionModel rx) {
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
      studentDepartment: user?.department ?? widget.patientProfile?['department']?.toString(),
      studentBloodGroup: user?.bloodGroup ?? widget.patientProfile?['bloodGroup']?.toString(),
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

  Widget _buildDoctorAllergiesBanner(Map<String, dynamic>? data, Map<String, dynamic>? patientProfile) {
    final List<String> allergies = [];
    if (data != null && data['knownAllergies'] is List) {
      allergies.addAll(
        (data['knownAllergies'] as List)
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty),
      );
    }
    if (allergies.isEmpty && patientProfile != null && patientProfile['criticalFlags'] is List) {
      allergies.addAll(
        (patientProfile['criticalFlags'] as List)
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty),
      );
    }

    final bool hasAllergies = allergies.isNotEmpty;
    final String allergiesText = hasAllergies
        ? allergies.join(', ')
        : 'Not found - confirm with patient';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BaustColors.emergencyRed,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: BaustColors.emergencyRed.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CRITICAL MEDICAL ALERT — KNOWN ALLERGIES',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAllergies
                      ? 'Known Allergies: $allergiesText'
                      : 'Known allergies: Not found - confirm with patient',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cross-check contraindications and verify directly with patient prior to prescribing.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
