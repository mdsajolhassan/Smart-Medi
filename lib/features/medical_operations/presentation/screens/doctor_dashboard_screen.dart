import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/services/fcm_notification_service.dart';
import '../../../../core/widgets/smart_medi_drawer.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../blood_bank/presentation/screens/blood_donor_directory.dart';
import '../controllers/patient_checkin_controller.dart';
import 'patient_checkin_log_screen.dart';
import 'patient_lookup_screen.dart';
import 'pharmacist_inventory_screen.dart';

enum DoctorStatus { available, inConsultation, emergencyDuty, offDuty }

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const DoctorDashboardScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen> {
  late int _currentIndex;
  DoctorStatus _currentStatus = DoctorStatus.available;
  int _currentTokenNumber = 0;
  int _waitingQueueCount = 0;

  // Active Emergency SOS List (Real-time live Firestore data, initial empty)
  final List<Map<String, dynamic>> _activeEmergencyAlerts = [];
  StreamSubscription<QuerySnapshot>? _sosSubscription;

  // Dynamic Digital Sick Leaves Granted by Doctor
  final List<Map<String, dynamic>> _grantedSickLeaves = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _listenToEmergencyAlerts();
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    super.dispose();
  }

  void _listenToEmergencyAlerts() {
    try {
      _sosSubscription = FirebaseFirestore.instance
          .collection(FirestoreCollections.emergencyAlerts)
          .orderBy('triggeredAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        final List<Map<String, dynamic>> liveAlerts = [];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final status = (data['status'] ?? 'TRIGGERED').toString();
          if (status != 'RESOLVED') {
            final triggeredAt = data['triggeredAt'];
            String timeDisplay = 'Just now';
            if (triggeredAt is Timestamp) {
              final diff = DateTime.now().difference(triggeredAt.toDate());
              if (diff.inMinutes < 1) {
                timeDisplay = 'Just now';
              } else if (diff.inMinutes < 60) {
                timeDisplay = '${diff.inMinutes} mins ago';
              } else {
                timeDisplay = '${diff.inHours} hours ago';
              }
            }

            liveAlerts.add({
              'alertId': data['alertId'] ?? doc.id,
              'studentName': data['studentName'] ?? 'Unknown Student',
              'roll': data['studentRoll'] ?? data['studentId'] ?? 'N/A',
              'department': data['department'] ?? 'General',
              'hall': data['hall'] ?? 'Campus Area',
              'room': data['roomNumber'] ?? 'N/A',
              'symptom': data['symptomCategory'] ?? 'Critical Emergency',
              'optionalNote': data['optionalNote'] ?? '',
              'criticalFlags': List<String>.from(data['criticalFlags'] ?? []),
              'blood': (data['criticalFlags'] != null && (data['criticalFlags'] as List).isNotEmpty)
                  ? (data['criticalFlags'] as List).first.toString()
                  : 'EMERGENCY',
              'time': timeDisplay,
              'status': status,
              'emergencyContact': data['emergencyContact'],
            });
          }
        }

        if (mounted) {
          setState(() {
            _activeEmergencyAlerts.clear();
            _activeEmergencyAlerts.addAll(liveAlerts);
          });
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _dispatchAmbulance(int index) {
    final alert = _activeEmergencyAlerts[index];
    final alertId = alert['alertId'];

    setState(() {
      alert['status'] = 'AMBULANCE_DISPATCHED';
    });

    try {
      FirebaseFirestore.instance
          .collection(FirestoreCollections.emergencyAlerts)
          .doc(alertId)
          .update({
        'status': 'AMBULANCE_DISPATCHED',
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BaustColors.successGreen,
        content: Row(
          children: [
            const Icon(Icons.airport_shuttle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'BAUST Ambulance dispatched to ${alert['hall']} (${alert['room']}) for ${alert['studentName']}!',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resolveAlert(int index) {
    final alert = _activeEmergencyAlerts[index];
    final alertId = alert['alertId'];

    setState(() {
      _activeEmergencyAlerts.removeAt(index);
    });

    try {
      FirebaseFirestore.instance
          .collection(FirestoreCollections.emergencyAlerts)
          .doc(alertId)
          .update({
        'status': 'RESOLVED',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BaustColors.primaryNavy,
        content: Text('Emergency for ${alert['studentName']} resolved and closed.'),
      ),
    );
  }

  void _logAlertToCheckIn(int index) {
    final alert = _activeEmergencyAlerts[index];
    final user = ref.read(authControllerProvider).userProfile;
    final staffInfo = '${user?.displayName ?? "Medical Doctor"} (${user?.designation ?? "Doctor"})';

    ref.read(patientCheckInProvider.notifier).logFromEmergencyAlert(
          studentId: alert['roll'] ?? 'N/A',
          studentName: alert['studentName'] ?? 'Unknown Student',
          symptom: alert['symptom'] ?? 'Critical Emergency',
          recordedBy: staffInfo,
          hall: alert['hall'],
          room: alert['room'],
        );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BaustColors.successGreen,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Documented in Medical Center Staff Log for ${alert['studentName']}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _simulateIncomingSos() {
    final newAlert = {
      'alertId': 'sos_sim_${DateTime.now().millisecondsSinceEpoch}',
      'studentName': 'MD. Sajol Hassan',
      'roll': '0802420205101137',
      'department': 'Dept of CSE',
      'hall': 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
      'room': '402-B',
      'symptom': 'Acute Chest Pain / Respiratory Distress',
      'optionalNote': 'Patient conscious in room, needs prompt medical evaluation.',
      'blood': 'B+',
      'criticalFlags': ['Asthma History'],
      'time': 'Just now',
      'status': 'TRIGGERED',
    };

    setState(() {
      _activeEmergencyAlerts.insert(0, newAlert);
    });

    ref.read(fcmNotificationServiceProvider).triggerSimulatedIncomingAlert(
          studentName: 'MD. Sajol Hassan',
          hall: 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
          room: '402-B',
          symptom: 'Acute Chest Pain / Respiratory Distress',
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: BaustColors.emergencyRed,
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('HIGH-PRIORITY SOS: MD. Sajol Hassan (0802420205101137)!')),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showGrantSickLeaveSheet({
    String? initialName,
    String? initialRoll,
    String? initialDept,
    String? initialDiagnosis,
  }) {
    final nameController = TextEditingController(text: initialName ?? '');
    final rollController = TextEditingController(text: initialRoll ?? '');
    final diagnosisController = TextEditingController(
      text: initialDiagnosis ?? 'Acute Clinical Exacerbation',
    );
    final noteController = TextEditingController(
      text: 'Strict bed rest advised. Exempt from laboratory work and tests.',
    );
    int selectedDays = 3;
    String selectedDept = initialDept ?? 'Dept of CSE';

    final departmentOptions = [
      'Dept of CSE',
      'Dept of EEE',
      'Dept of ME',
      'Dept of IPE',
      'Dept of Civil Engineering',
      'School of Business (BBA)',
      'Dept of English',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final now = DateTime.now();
            final endDate = now.add(Duration(days: selectedDays));
            final dateRangeStr =
                '${now.day}/${now.month}/${now.year} to ${endDate.day}/${endDate.month}/${endDate.year}';

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sheet Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.note_alt_outlined,
                            color: BaustColors.primaryArmyGreen,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grant Digital Sick Leave',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: BaustColors.textDark,
                                ),
                              ),
                              Text(
                                'Official BAUST Medical Certificate Dispatch',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BaustColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Student Information Fields
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Student Name',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: rollController,
                            decoration: const InputDecoration(
                              labelText: 'Student Roll',
                              prefixIcon: Icon(Icons.pin_outlined, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Academic Department Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedDept,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.school_outlined, size: 20),
                      ),
                      items: departmentOptions.map((dept) {
                        return DropdownMenuItem(
                          value: dept,
                          child: Text(dept, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDept = val);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Day Selector (1 to 14 days)
                    const Text(
                      'SICK LEAVE DURATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: BaustColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      children: [1, 2, 3, 5, 7, 10, 14].map((days) {
                        final isSelected = selectedDays == days;
                        return ChoiceChip(
                          selected: isSelected,
                          label: Text(
                            '$days ${days == 1 ? "Day" : "Days"}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isSelected ? Colors.white : BaustColors.textDark,
                            ),
                          ),
                          selectedColor: BaustColors.primaryArmyGreen,
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (_) {
                            setModalState(() => selectedDays = days);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 10),

                    // Active Date Window Banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BaustColors.primaryArmyGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            size: 18,
                            color: BaustColors.primaryArmyGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Valid Period: $dateRangeStr ($selectedDays ${selectedDays == 1 ? "day" : "days"})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: BaustColors.primaryArmyGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Diagnosis Input
                    TextField(
                      controller: diagnosisController,
                      decoration: const InputDecoration(
                        labelText: 'Clinical Diagnosis / Medical Reason',
                        prefixIcon: Icon(Icons.healing_outlined, size: 20),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Doctor's Note / Remarks
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Doctor's Recommendation & Instructions",
                        prefixIcon: Icon(Icons.medical_information_outlined, size: 20),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Automatic Notification Disclaimer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.send_rounded, size: 18, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Automated Academic Dispatch: Submitting this leave will instantly notify '
                              'the Head of Department (Dr. Md Nakib Hayat Chowdhury, 01769675560) '
                              'with a certified digital leave slip.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.brown.shade900,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Dispatch Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BaustColors.primaryArmyGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'GRANT & DISPATCH SICK LEAVE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      onPressed: () {
                        final studentName = nameController.text.trim();
                        final studentRoll = rollController.text.trim();
                        final diagnosis = diagnosisController.text.trim();
                        final note = noteController.text.trim();

                        if (studentName.isEmpty || studentRoll.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: BaustColors.emergencyRed,
                              content: Text('Please provide student name and roll number.'),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(modalContext);

                        final newLeave = {
                          'leaveId': 'SL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                          'studentName': studentName,
                          'studentRoll': studentRoll,
                          'department': selectedDept,
                          'days': selectedDays,
                          'startDate': '${now.day}/${now.month}/${now.year}',
                          'endDate': '${endDate.day}/${endDate.month}/${endDate.year}',
                          'diagnosis': diagnosis,
                          'doctorNote': note,
                          'headOfDept': 'Dr. Md Nakib Hayat Chowdhury (Head of Department, CSE - 01769675560)',
                          'status': 'APPROVED & DISPATCHED',
                        };

                        setState(() {
                          _grantedSickLeaves.insert(0, newLeave);
                        });

                        try {
                          FirebaseFirestore.instance.collection('sick_leaves').add({
                            ...newLeave,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } catch (_) {}

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: BaustColors.successGreen,
                            duration: const Duration(seconds: 4),
                            content: Row(
                              children: [
                                const Icon(Icons.task_alt, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Sick leave granted for $studentName ($selectedDays ${selectedDays == 1 ? "day" : "days"})! '
                                    'Dispatched to Head of Department (CSE).',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQuickPrescriptionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.document_scanner, color: BaustColors.primaryArmyGreen, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Paper Prescription',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BaustColors.textDark),
                      ),
                      Text(
                        'AI extraction with immediate form pre-fill',
                        style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Select a student patient to attach this digital prescription to:',
              style: TextStyle(fontSize: 13, color: BaustColors.textDark),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: const Icon(Icons.search, color: BaustColors.primaryNavy),
              title: const Text('Search by Student ID / Roll', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Lookup student records in directory', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 1);
              },
            ),
            if (_activeEmergencyAlerts.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Active Emergency SOS Students:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.emergencyRed),
              ),
              const SizedBox(height: 6),
              ..._activeEmergencyAlerts.take(3).map((alert) {
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.shade100),
                  ),
                  tileColor: Colors.red.shade50.withValues(alpha: 0.5),
                  leading: const Icon(Icons.emergency, color: BaustColors.emergencyRed, size: 20),
                  title: Text(alert['studentName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  subtitle: Text('Roll: ${alert['roll']} • ${alert['department']}', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: BaustColors.emergencyRed),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientLookupScreen(initialQuery: alert['roll']?.toString()),
                      ),
                    );
                  },
                );
              }),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;

    final tabs = [
      _buildClinicalDutyTab(user),
      const PatientLookupScreen(showAppBar: false),
      const PharmacistInventoryScreen(showAppBar: false),
    ];

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
                'Doctor Portal — BAUST Medical Center',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = MediaQuery.sizeOf(context).width >= 960;
              if (isWide) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Patient Lookup',
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: BaustColors.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.person_search_outlined, size: 18),
                        label: const Text('Lookup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PatientLookupScreen()),
                          );
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Patient Check-in Log',
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: BaustColors.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                        label: const Text('Check-in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()),
                          );
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Pharmacy Inventory',
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: BaustColors.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.medication_outlined, size: 18),
                        label: const Text('Pharmacy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PharmacistInventoryScreen()),
                          );
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Blood Donor Directory',
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: BaustColors.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                        label: const Text('Blood Bank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BloodDonorDirectoryScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              return PopupMenuButton<String>(
                tooltip: 'Medical Center Modules',
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.widgets_outlined, size: 20),
                    SizedBox(width: 4),
                    Text('Modules', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                onSelected: (value) {
                  if (value == 'lookup') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PatientLookupScreen()),
                    );
                  } else if (value == 'checkin') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()),
                    );
                  } else if (value == 'pharmacy') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PharmacistInventoryScreen()),
                    );
                  } else if (value == 'blood') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BloodDonorDirectoryScreen()),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'lookup',
                    child: Row(
                      children: [
                        Icon(Icons.person_search_outlined, size: 18, color: BaustColors.primaryNavy),
                        SizedBox(width: 10),
                        Text('Patient Lookup'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'checkin',
                    child: Row(
                      children: [
                        Icon(Icons.assignment_ind_outlined, size: 18, color: BaustColors.primaryNavy),
                        SizedBox(width: 10),
                        Text('Patient Check-in Log'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pharmacy',
                    child: Row(
                      children: [
                        Icon(Icons.medication_outlined, size: 18, color: BaustColors.primaryNavy),
                        SizedBox(width: 10),
                        Text('Pharmacy Inventory'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'blood',
                    child: Row(
                      children: [
                        Icon(Icons.volunteer_activism_outlined, size: 18, color: BaustColors.primaryNavy),
                        SizedBox(width: 10),
                        Text('Blood Donor Directory'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: 'Simulate Incoming SOS Alert',
            icon: const Icon(Icons.notification_add_outlined),
            onPressed: _simulateIncomingSos,
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'doctor_fab_scan',
        backgroundColor: BaustColors.primaryArmyGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text(
          'Scan Prescription',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        tooltip: 'Scan Paper Prescription',
        onPressed: _showQuickPrescriptionPicker,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: _currentIndex == 0
            ? Colors.red.shade100
            : BaustColors.primaryArmyGreen.withValues(alpha: 0.15),
        backgroundColor: Colors.white,
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined),
            selectedIcon: Icon(Icons.emergency, color: BaustColors.emergencyRed),
            label: 'SOS & Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_search_outlined),
            selectedIcon: Icon(Icons.person_search, color: BaustColors.primaryArmyGreen),
            label: 'Student Directory',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication, color: BaustColors.primaryArmyGreen),
            label: 'Pharmacy',
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalDutyTab(UserProfile? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor Profile & Duty Card
          _buildDoctorHeader(user),

          const SizedBox(height: 14),

          // Quick Operational Actions Row
          _buildQuickActionsRow(),

          const SizedBox(height: 16),

          // Live Availability Status Toggle
          _buildStatusToggleSection(),

          const SizedBox(height: 16),

          // Active Emergency SOS Alerts Section
          _buildEmergencySection(),

          const SizedBox(height: 16),

          // Patient Check-in Tracker Section (Task 4)
          _buildPatientCheckInSection(),

          const SizedBox(height: 16),

          // Consultation Queue & Schedule Row
          _buildQueueAndScheduleRow(),

          const SizedBox(height: 16),

          // Digital Sick Leave Registry Section
          _buildSickLeaveRegisterSection(),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Column(
      children: [
        // Patient Lookup Action
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: BaustColors.navyDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.person_search, size: 20),
            label: const Text(
              'Patient Lookup (Student ID & Medical History)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientLookupScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Grant Sick Leave Primary Action
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BaustColors.primaryArmyGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.note_alt, size: 18),
                label: const Text(
                  'Grant Sick Leave',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _showGrantSickLeaveSheet(),
              ),
            ),
            const SizedBox(width: 10),
            // Patient Check-In Log Action (Task 4)
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BaustColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.assignment_ind, size: 18),
                label: const Text(
                  'Patient Check-In Log',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Pharmacist Inventory Navigation
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BaustColors.primaryArmyGreen,
                  side: const BorderSide(color: BaustColors.primaryArmyGreen),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.medication_outlined, size: 18),
                label: const Text(
                  'Pharmacy Inventory',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PharmacistInventoryScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            // Smart Blood Bank Directory Action
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BaustColors.emergencyRed,
                  side: const BorderSide(color: BaustColors.emergencyRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.volunteer_activism, size: 18),
                label: const Text(
                  'Smart Blood Bank',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BloodDonorDirectoryScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPatientCheckInSection() {
    final checkIns = ref.watch(patientCheckInProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_ind, color: BaustColors.primaryNavy, size: 18),
                SizedBox(width: 6),
                Text(
                  'PATIENT CHECK-IN & VISIT TRACKER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: BaustColors.primaryNavy,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('View All Logs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: BaustColors.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (checkIns.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No patient check-in records logged yet today.',
                    style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                  ),
                )
              else
                ...checkIns.take(3).map((item) {
                  final isEmergency = item.purpose.toLowerCase().contains('emergency') || item.purpose.toLowerCase().contains('sos');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEmergency ? Colors.red.shade50 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isEmergency ? Colors.red.shade200 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isEmergency ? Colors.red.shade100 : BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                          child: Icon(
                            isEmergency ? Icons.warning_amber_rounded : Icons.person,
                            size: 16,
                            color: isEmergency ? BaustColors.emergencyRed : BaustColors.primaryArmyGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.studentName} (ID: ${item.studentId})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'Purpose: ${item.purpose}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isEmergency ? BaustColors.emergencyRed : BaustColors.textMuted,
                                  fontWeight: isEmergency ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEmergency ? Colors.red.shade100 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isEmergency ? BaustColors.emergencyRed : BaustColors.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BaustColors.primaryNavy,
                    side: const BorderSide(color: BaustColors.primaryNavy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Record New Check-In Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorHeader(UserProfile? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: BaustColors.primaryNavy.withValues(alpha: 0.1),
            child: const Icon(Icons.medical_services, size: 34, color: BaustColors.primaryNavy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Doctor',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 2),
                Builder(
                  builder: (context) {
                    final reg = user?.bmdcRegistrationNumber?.trim();
                    final rawDesig = user?.designation?.trim();
                    final designation = (rawDesig != null && rawDesig.isNotEmpty)
                        ? rawDesig
                        : 'Senior Medical Officer, BAUST Medical Center';
                    final subtitle = (reg != null && reg.isNotEmpty)
                        ? 'BMDC Reg: $reg • $designation'
                        : designation;
                    return Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(_currentStatus),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusLabel(_currentStatus),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(_currentStatus),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusToggleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DUTY AVAILABILITY TOGGLE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: BaustColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<DoctorStatus>(
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: const [
              ButtonSegment(
                value: DoctorStatus.available,
                label: Text('Available', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.check_circle_outline, size: 16),
              ),
              ButtonSegment(
                value: DoctorStatus.inConsultation,
                label: Text('Busy', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.timer_outlined, size: 16),
              ),
              ButtonSegment(
                value: DoctorStatus.emergencyDuty,
                label: Text('Emergency', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.emergency_outlined, size: 16),
              ),
              ButtonSegment(
                value: DoctorStatus.offDuty,
                label: Text('Off Duty', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.power_settings_new, size: 16),
              ),
            ],
            selected: {_currentStatus},
            onSelectionChanged: (Set<DoctorStatus> newSelection) {
              setState(() => _currentStatus = newSelection.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySection() {
    final alertCount = _activeEmergencyAlerts.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: BaustColors.emergencyRed, size: 18),
                const SizedBox(width: 6),
                Text(
                  'LIVE EMERGENCY SOS ALERTS ($alertCount)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: BaustColors.emergencyRed,
                  ),
                ),
              ],
            ),
            if (alertCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BaustColors.emergencyRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'HIGH PRIORITY',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_activeEmergencyAlerts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: BaustColors.successGreen, size: 24),
                SizedBox(width: 12),
                Text(
                  'No active campus medical emergencies at this moment.',
                  style: TextStyle(fontSize: 13, color: BaustColors.textDark),
                ),
              ],
            ),
          )
        else
          ..._activeEmergencyAlerts.asMap().entries.map((entry) {
            final idx = entry.key;
            final alert = entry.value;
            final isDispatched = alert['status'] == 'AMBULANCE_DISPATCHED';

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: BaustColors.emergencyRed, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: const Icon(Icons.warning, color: BaustColors.emergencyRed),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert['studentName'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                (alert['hall'] as String).toLowerCase().contains('non-resident')
                                    ? 'Roll: ${alert['roll']} • Address: ${alert['hall']} (${alert['room']})'
                                    : 'Roll: ${alert['roll']} • Hall: ${alert['hall']}, Room ${alert['room']}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            alert['blood'],
                            style: const TextStyle(
                              color: BaustColors.emergencyRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Text(
                      'Reported Symptom: ${alert['symptom']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (alert['optionalNote'] != null && (alert['optionalNote'] as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Emergency Note: ${alert['optionalNote']}',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                    if (alert['emergencyContact'] != null && alert['emergencyContact'] is Map) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Contact: ${alert['emergencyContact']['name']} (${alert['emergencyContact']['relationship']}) - ${alert['emergencyContact']['phone']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BaustColors.emergencyRed,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: (alert['criticalFlags'] as List).map<Widget>((flag) {
                        return Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.amber.shade100,
                          label: Text(
                            flag.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown.shade900,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDispatched ? BaustColors.successGreen : BaustColors.emergencyRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(isDispatched ? Icons.check : Icons.airport_shuttle),
                            label: Text(
                              isDispatched ? 'AMBULANCE ON ROUTE' : 'DISPATCH AMBULANCE',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: isDispatched ? null : () => _dispatchAmbulance(idx),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BaustColors.textDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _resolveAlert(idx),
                          child: const Text('Resolve', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BaustColors.primaryArmyGreen,
                              side: const BorderSide(color: BaustColors.primaryArmyGreen),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.note_alt_outlined, size: 15),
                            label: const Text(
                              'Grant Sick Leave',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _showGrantSickLeaveSheet(
                              initialName: alert['studentName'],
                              initialRoll: alert['roll'],
                              initialDiagnosis: alert['symptom'],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BaustColors.primaryNavy,
                              side: const BorderSide(color: BaustColors.primaryNavy),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.assignment_ind_outlined, size: 15),
                            label: const Text(
                              'Document Check-In',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _logAlertToCheckIn(idx),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildQueueAndScheduleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Queue Counter Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT TOKEN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentTokenNumber > 0 ? '#$_currentTokenNumber' : 'Queue not started',
                  style: TextStyle(
                    fontSize: _currentTokenNumber > 0 ? 28 : 17,
                    fontWeight: FontWeight.w900,
                    color: BaustColors.primaryNavy,
                  ),
                ),
                Text(
                  _currentTokenNumber > 0
                      ? '$_waitingQueueCount in waiting queue'
                      : 'Queue not started',
                  style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BaustColors.primaryNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _currentTokenNumber++;
                      if (_waitingQueueCount > 0) _waitingQueueCount--;
                    });
                  },
                  child: Text(_currentTokenNumber > 0 ? 'Next Token' : 'Start Queue', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Visiting Hours Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VISITING HOURS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.textMuted),
                ),
                SizedBox(height: 8),
                Text(
                  '• Morning Shift:\n  08:00 AM - 02:00 PM',
                  style: TextStyle(fontSize: 11, height: 1.3),
                ),
                SizedBox(height: 6),
                Text(
                  '• Evening Shift:\n  05:00 PM - 08:00 PM',
                  style: TextStyle(fontSize: 11, height: 1.3),
                ),
                SizedBox(height: 6),
                Text(
                  '• Emergency Coverage:\n  24/7 on Campus Call',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.emergencyRed),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSickLeaveRegisterSection() {
    return Container(
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
                  const Icon(Icons.assignment_turned_in, color: BaustColors.primaryArmyGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'DIGITAL SICK LEAVE REGISTER (${_grantedSickLeaves.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: BaustColors.primaryArmyGreen,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.add, size: 16, color: BaustColors.primaryArmyGreen),
                label: const Text(
                  'Issue Leave',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: BaustColors.primaryArmyGreen,
                  ),
                ),
                onPressed: () => _showGrantSickLeaveSheet(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_grantedSickLeaves.isEmpty)
            const Text(
              'No sick leaves issued yet.',
              style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
            )
          else
            ..._grantedSickLeaves.map((leave) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${leave['studentName']} (${leave['studentRoll']})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${leave['department']} • Leave ID: ${leave['leaveId']}',
                                style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: BaustColors.primaryArmyGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${leave['days']} Days Leave',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: BaustColors.primaryArmyGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'Diagnosis: ${leave['diagnosis']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (leave['doctorNote'] != null && leave['doctorNote'].toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Note: ${leave['doctorNote']}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: BaustColors.successGreen),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Dispatched to Head of Department (CSE)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: BaustColors.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _getStatusColor(DoctorStatus status) {
    switch (status) {
      case DoctorStatus.available:
        return BaustColors.successGreen;
      case DoctorStatus.inConsultation:
        return Colors.amber.shade700;
      case DoctorStatus.emergencyDuty:
        return BaustColors.emergencyRed;
      case DoctorStatus.offDuty:
        return Colors.grey;
    }
  }

  String _getStatusLabel(DoctorStatus status) {
    switch (status) {
      case DoctorStatus.available:
        return 'Available for Consultations';
      case DoctorStatus.inConsultation:
        return 'In Consultation (Busy)';
      case DoctorStatus.emergencyDuty:
        return 'On Active Emergency Duty';
      case DoctorStatus.offDuty:
        return 'Off Duty';
    }
  }
}
