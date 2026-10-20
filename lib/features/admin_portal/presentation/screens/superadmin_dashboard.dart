import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/auth_config.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/smart_medi_drawer.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../medical_operations/presentation/screens/doctor_dashboard_screen.dart';
import '../../../medical_operations/presentation/screens/patient_checkin_log_screen.dart';
import '../../../medical_operations/presentation/screens/pharmacist_inventory_screen.dart';

class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  // Pre-populated real faculty items with Firestore sync capability
  final List<Map<String, String?>> _provisionedFaculty = List.from(BaustSeedData.initialFaculty);
  String _selectedFilter = 'All';

  // Registered System Accounts & Testing Overview
  String _accountFilter = 'All Accounts';
  String _accountSearchQuery = '';
  final TextEditingController _accountSearchController = TextEditingController();

  StreamSubscription? _sosSubscription;
  final List<Map<String, dynamic>> _activeEmergencyAlerts = [];

  // Static baseline roster of system accounts for BAUST Smart Medi
  static final List<Map<String, dynamic>> _initialSystemAccounts = [
    {
      'name': 'MD. Sajol Hasan',
      'email': AuthConfig.superAdminEmail,
      'role': 'superadmin',
      'roleDisplay': 'Super Administrator',
      'department': 'Central Administration / IT Cell',
      'designation': 'Chief System Architect & SuperAdmin',
      'status': 'Verified & Absolute Access',
      'isSuperAdmin': true,
      'badgeColor': const Color(0xFFF59E0B),
    },
    {
      'name': 'MD. Sajol Hassan',
      'email': '0802420205101137@baust.edu.bd',
      'studentRoll': '0802420205101137',
      'role': 'student',
      'roleDisplay': 'Student',
      'department': 'Computer Science & Engineering (CSE)',
      'hall': 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
      'room': '402-B',
      'blood': 'B+',
      'status': 'Verified & Active Student',
      'badgeColor': BaustColors.primaryArmyGreen,
    },
    {
      'name': 'Dr. Fowzia Jahan',
      'email': 'medicalcenter@baust.edu.bd',
      'phone': '01769-675576',
      'role': 'doctor',
      'roleDisplay': 'Senior Medical Officer / Doctor',
      'department': 'BAUST Medical Center',
      'designation': 'Senior Medical Officer',
      'status': 'Approved Medical Doctor',
      'badgeColor': BaustColors.emergencyRed,
    },
    {
      'name': 'Md. Mozaffor Hossain',
      'email': null,
      'phone': '01712-645975',
      'role': 'pharmacist',
      'roleDisplay': 'Medical Assistant / Pharmacist',
      'department': 'BAUST Medical Center',
      'designation': 'Medical Assistant & Pharmacist',
      'status': 'Approved Pharmacist & Medical Assistant',
      'badgeColor': BaustColors.primaryArmyGreen,
    },
    {
      'name': 'Lamia Aktar Limu',
      'email': 'limuakhtar9@gmail.com',
      'phone': '01749-898473',
      'role': 'nurse',
      'roleDisplay': 'Staff Nurse',
      'department': 'BAUST Medical Center',
      'designation': 'Staff Nurse',
      'status': 'Approved Nurse',
      'badgeColor': const Color(0xFF0284C7),
    },
    {
      'name': 'Dr. Md Nakib Hayat Chowdhury',
      'email': null,
      'phone': '01769675560',
      'role': 'staff',
      'roleDisplay': 'Head of Department (CSE)',
      'department': 'Computer Science & Engineering (CSE)',
      'designation': 'Head of Department (CSE) / Associate Professor',
      'status': 'Head of Department',
      'badgeColor': BaustColors.primaryNavy,
    },
  ];

  late final List<Map<String, dynamic>> _systemAccounts;

  @override
  void initState() {
    super.initState();
    _systemAccounts = List.from(_initialSystemAccounts);

    // Initial simulated active SOS from student Sajol Hassan for instant testing
    _activeEmergencyAlerts.add({
      'alertId': 'sos_init_sajol',
      'studentName': 'MD. Sajol Hassan',
      'studentRoll': '0802420205101137',
      'department': 'Dept of CSE',
      'hall': 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
      'room': '402-B',
      'symptom': 'Acute Chest Pain / Respiratory Distress',
      'blood': 'B+',
      'time': 'Just now',
      'status': 'TRIGGERED',
      'emergencyContact': 'Campus Emergency Roster',
      'criticalFlags': ['Asthma History', 'Penicillin Allergy'],
    });

    _listenToEmergencyAlerts();
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    _accountSearchController.dispose();
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
            liveAlerts.add({
              'alertId': data['alertId'] ?? doc.id,
              'studentName': data['studentName'] ?? 'Unknown Student',
              'studentRoll': data['studentRoll'] ?? data['studentId'] ?? 'N/A',
              'department': data['department'] ?? 'General',
              'hall': data['hall'] ?? 'Campus Area',
              'room': data['roomNumber'] ?? 'N/A',
              'symptom': data['symptomCategory'] ?? 'Critical Emergency',
              'blood': 'B+',
              'time': 'Active',
              'status': status,
              'emergencyContact': data['emergencyContact'],
              'criticalFlags': List<String>.from(data['criticalFlags'] ?? []),
            });
          }
        }

        if (mounted && liveAlerts.isNotEmpty) {
          setState(() {
            _activeEmergencyAlerts.clear();
            _activeEmergencyAlerts.addAll(liveAlerts);
          });
        }
      }, onError: (_) {});
    } catch (_) {
      // Offline / unit test safe fallback
    }
  }

  void _dispatchAmbulance(int index) {
    if (index >= _activeEmergencyAlerts.length) return;
    final alert = _activeEmergencyAlerts[index];

    setState(() {
      alert['status'] = 'AMBULANCE_DISPATCHED';
    });

    try {
      final alertId = alert['alertId'];
      FirebaseFirestore.instance
          .collection(FirestoreCollections.emergencyAlerts)
          .doc(alertId)
          .update({
        'status': 'AMBULANCE_DISPATCHED',
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    ScaffoldMessenger.of(context).clearSnackBars();
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

  void _simulateStudentSos() {
    final newAlert = {
      'alertId': 'sos_sim_${DateTime.now().millisecondsSinceEpoch}',
      'studentName': 'MD. Sajol Hassan',
      'studentRoll': '0802420205101137',
      'department': 'Dept of CSE',
      'hall': 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
      'room': '402-B',
      'symptom': 'Severe Asthma Exacerbation / Acute Chest Pain',
      'blood': 'B+',
      'time': 'Just now',
      'status': 'TRIGGERED',
      'emergencyContact': 'Campus Emergency Roster',
      'criticalFlags': ['Asthma History', 'Penicillin Allergy'],
    };

    setState(() {
      _activeEmergencyAlerts.insert(0, newAlert);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: BaustColors.emergencyRed,
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('[Test Tool] Simulated SOS triggered for Student MD. Sajol Hassan (0802420205101137)!'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddFacultyModal() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedDept = BaustDepartments.departments.first;
    String selectedDesignation = FacultyDesignations.designations.first;
    String selectedRole = FacultyAccessRoles.roles.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Provision Faculty Role',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.primaryNavy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'Assign hierarchical role and institutional designations dynamically.',
                    style: TextStyle(color: BaustColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Name
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Faculty Full Name',
                      hintText: 'e.g. Dr. Md. Enamul Kabir',
                      prefixIcon: Icon(Icons.person_outline, color: BaustColors.primaryNavy),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Institutional Email',
                      hintText: 'faculty@baust.edu.bd',
                      prefixIcon: Icon(Icons.email_outlined, color: BaustColors.primaryNavy),
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Valid university email is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Phone Number
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number (Optional)',
                      hintText: '01712345678',
                      prefixIcon: Icon(Icons.phone_outlined, color: BaustColors.primaryNavy),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Department
                  DropdownButtonFormField<String>(
                    initialValue: selectedDept,
                    decoration: const InputDecoration(
                      labelText: 'Academic Department / Wing',
                      prefixIcon: Icon(Icons.domain, color: BaustColors.primaryNavy),
                    ),
                    items: BaustDepartments.departments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedDept = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Designation
                  DropdownButtonFormField<String>(
                    initialValue: selectedDesignation,
                    decoration: const InputDecoration(
                      labelText: 'Institutional Designation',
                      prefixIcon: Icon(Icons.workspace_premium, color: BaustColors.primaryNavy),
                    ),
                    items: FacultyDesignations.designations
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedDesignation = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Role / Access Level
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Hierarchical Access Level',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: BaustColors.emergencyRed),
                    ),
                    items: FacultyAccessRoles.roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedRole = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BaustColors.primaryNavy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Provision & Assign Role', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final newFaculty = {
                          'name': nameController.text.trim(),
                          'designation': selectedDesignation,
                          'department': selectedDept,
                          'email': emailController.text.trim().toLowerCase(),
                          'phone': phoneController.text.trim(),
                          'accessLevel': selectedRole,
                        };

                        setState(() {
                          _provisionedFaculty.insert(0, newFaculty);
                        });

                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: BaustColors.successGreen,
                            content: Text('Successfully provisioned ${newFaculty['name']} as ${newFaculty['accessLevel']}!'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, String?>> _filteredFaculty() {
    return _provisionedFaculty.where((f) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'BAUST Medical Center') {
        return f['department'] == 'BAUST Medical Center';
      }
      if (_selectedFilter == 'Central Administration') {
        return f['department'] == 'Central Administration' ||
            f['department'] == 'Examination Wing';
      }
      if (_selectedFilter == 'Academic Departments') {
        return f['department'] != 'BAUST Medical Center' &&
            f['department'] != 'Central Administration' &&
            f['department'] != 'Examination Wing';
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _filteredSystemAccounts() {
    return _systemAccounts.where((acc) {
      final role = (acc['role'] ?? '').toString().toLowerCase();

      final matchesFilter = _accountFilter == 'All Accounts' ||
          (_accountFilter == 'Students' && role == 'student') ||
          (_accountFilter == 'Doctors' && role == 'doctor') ||
          (_accountFilter == 'Pharmacists & Nurses' && (role == 'pharmacist' || role == 'nurse')) ||
          (_accountFilter == 'SuperAdmin' && (role == 'superadmin' || acc['isSuperAdmin'] == true));

      final q = _accountSearchQuery.toLowerCase().trim();
      final name = (acc['name'] ?? '').toString().toLowerCase();
      final email = (acc['email'] ?? '').toString().toLowerCase();
      final phone = (acc['phone'] ?? '').toString().toLowerCase();
      final roll = (acc['studentRoll'] ?? '').toString().toLowerCase();
      final dept = (acc['department'] ?? '').toString().toLowerCase();

      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          roll.contains(q) ||
          dept.contains(q);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;
    final filteredAccounts = _filteredSystemAccounts();

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
                'SuperAdmin — System Hierarchy',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Simulate Student SOS (Test Tool)',
            icon: const Icon(Icons.notification_add_outlined, color: BaustColors.emergencyRed),
            onPressed: _simulateStudentSos,
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [BaustColors.navyDark, BaustColors.primaryNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: const Icon(Icons.shield, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'MD. Sajol Hasan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${user?.email ?? AuthConfig.superAdminEmail} • Absolute SuperAdmin',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'System Accounts & Testing Portal (Full Management Privileges)',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Metrics Summary Row
            Row(
              children: [
                _buildStatCard(
                  title: 'Registered Accounts',
                  count: '${_systemAccounts.length}',
                  icon: Icons.people_alt_outlined,
                  color: BaustColors.navyLight,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: 'Medical Center',
                  count: '${_systemAccounts.where((a) => a['role'] == 'doctor' || a['role'] == 'pharmacist' || a['role'] == 'nurse').length}',
                  icon: Icons.local_hospital_outlined,
                  color: BaustColors.emergencyRed,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: 'Active Students',
                  count: '${_systemAccounts.where((a) => a['role'] == 'student').length}',
                  icon: Icons.school_outlined,
                  color: BaustColors.successGreen,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Elevated Operational Portals Launcher
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dashboard_customize, size: 18, color: BaustColors.primaryNavy),
                      SizedBox(width: 8),
                      Text(
                        'Elevated Operations & Direct Portals',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            side: BorderSide(color: BaustColors.emergencyRed.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.local_hospital, color: BaustColors.emergencyRed, size: 18),
                          label: const Text(
                            'Doctor / SOS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.emergencyRed),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            side: BorderSide(color: BaustColors.primaryArmyGreen.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.medication, color: BaustColors.primaryArmyGreen, size: 18),
                          label: const Text(
                            'Pharmacy',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.primaryArmyGreen),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PharmacistInventoryScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            side: BorderSide(color: BaustColors.primaryNavy.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.assignment_ind, color: BaustColors.primaryNavy, size: 18),
                          label: const Text(
                            'Check-in Log',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.primaryNavy),
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
                ],
              ),
            ),

            const SizedBox(height: 20),

            // LIVE EMERGENCY SOS QUEUE & TESTING MONITOR (Task 3)
            _buildLiveSosTestingQueueSection(),

            const SizedBox(height: 24),

            // PENDING ACCOUNTS & STAFF APPROVAL
            _buildPendingAccountsSection(),

            const SizedBox(height: 24),

            // SYSTEM ACCOUNTS & TESTING OVERVIEW (Task 3)
            _buildSystemAccountsTestingSection(filteredAccounts),

            const SizedBox(height: 24),

            // ACCESS LOG AUDIT TRAIL
            _buildAccessLogsSection(),

            const SizedBox(height: 24),

            // FACULTY & STAFF HIERARCHY DIRECTORY
            _buildFacultyDirectorySection(),

            const SizedBox(height: 88),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BaustColors.primaryNavy,
        foregroundColor: Colors.white,
        onPressed: _openAddFacultyModal,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Faculty'),
      ),
    );
  }

  Widget _buildLiveSosTestingQueueSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BaustColors.emergencyRed.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: BaustColors.emergencyRed.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.emergency, color: BaustColors.emergencyRed, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'LIVE EMERGENCY SOS TESTING MONITOR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: BaustColors.emergencyRed,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BaustColors.emergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_alert, size: 14),
                label: const Text('Simulate SOS (Test Tool)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _simulateStudentSos,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Inspect incoming campus distress alerts triggered from student accounts with room & hall coordinates.',
            style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
          ),
          const SizedBox(height: 14),

          if (_activeEmergencyAlerts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No active emergency SOS alerts currently in queue.', style: TextStyle(fontSize: 12, color: BaustColors.textMuted)),
              ),
            )
          else
            ..._activeEmergencyAlerts.asMap().entries.map((entry) {
              final idx = entry.key;
              final alert = entry.value;
              final isDispatched = alert['status'] == 'AMBULANCE_DISPATCHED';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDispatched ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDispatched ? BaustColors.successGreen.withValues(alpha: 0.4) : Colors.red.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${alert['studentName']} (${alert['studentRoll']})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BaustColors.textDark),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDispatched ? BaustColors.successGreen : BaustColors.emergencyRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isDispatched ? 'AMBULANCE ON ROUTE' : 'TRIGGERED',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Location: ${alert['hall']} • Room ${alert['room']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BaustColors.primaryNavy),
                    ),
                    Text(
                      'Symptom: ${alert['symptom']}',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDispatched ? BaustColors.successGreen : BaustColors.emergencyRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(isDispatched ? Icons.check : Icons.airport_shuttle, size: 16),
                            label: Text(
                              isDispatched ? 'AMBULANCE DISPATCHED' : 'DISPATCH AMBULANCE',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: isDispatched ? null : () => _dispatchAmbulance(idx),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BaustColors.primaryNavy,
                            side: const BorderSide(color: BaustColors.primaryNavy),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Doctor Portal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSystemAccountsTestingSection(List<Map<String, dynamic>> filteredAccounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.manage_accounts, color: BaustColors.primaryNavy, size: 20),
                SizedBox(width: 8),
                Text(
                  'DEMO SYSTEM ACCOUNTS [TEST TOOLS]',
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
              '${filteredAccounts.length} Demo Accounts',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BaustColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '[Test Tools] Review baseline demo/test accounts (Students, Doctors, Pharmacists, Nurses, and SuperAdmin). These accounts are provided as test tools for system evaluation, not real records.',
          style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
        ),
        const SizedBox(height: 12),

        // Search Field
        TextField(
          controller: _accountSearchController,
          decoration: InputDecoration(
            hintText: 'Search accounts by name, student roll, email, or role...',
            prefixIcon: const Icon(Icons.search, size: 20, color: BaustColors.primaryNavy),
            suffixIcon: _accountSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _accountSearchController.clear();
                      setState(() => _accountSearchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          onChanged: (val) => setState(() => _accountSearchQuery = val),
        ),

        const SizedBox(height: 10),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              'All Accounts',
              'Students',
              'Doctors',
              'Pharmacists & Nurses',
              'SuperAdmin',
            ].map((cat) {
              final isSelected = _accountFilter == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  showCheckmark: false,
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BaustColors.textDark,
                    ),
                  ),
                  selectedColor: BaustColors.primaryNavy,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? BaustColors.primaryNavy : Colors.grey.shade300),
                  ),
                  onSelected: (_) => setState(() => _accountFilter = cat),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Accounts List
        if (filteredAccounts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No system accounts match the query.', style: TextStyle(fontSize: 12, color: BaustColors.textMuted)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredAccounts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final acc = filteredAccounts[index];
              final role = (acc['role'] ?? 'student').toString();
              final isSuperAdmin = acc['isSuperAdmin'] == true || role == 'superadmin';
              final isStudent = role == 'student';
              final isDoctor = role == 'doctor';
              final isPharmacy = role == 'pharmacist';
              final email = acc['email']?.toString();
              final hasEmail = email != null && email.trim().isNotEmpty;
              final phone = acc['phone']?.toString();
              final hasPhone = phone != null && phone.trim().isNotEmpty;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSuperAdmin
                        ? const Color(0xFFF59E0B)
                        : isDoctor
                            ? BaustColors.emergencyRed.withValues(alpha: 0.5)
                            : isStudent
                                ? BaustColors.primaryArmyGreen.withValues(alpha: 0.4)
                                : Colors.grey.shade200,
                    width: isSuperAdmin ? 1.5 : 1,
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
                            radius: 20,
                            backgroundColor: (acc['badgeColor'] as Color? ?? BaustColors.primaryNavy).withValues(alpha: 0.12),
                            child: Icon(
                              isSuperAdmin
                                  ? Icons.shield
                                  : isDoctor
                                      ? Icons.local_hospital
                                      : isStudent
                                          ? Icons.school
                                          : Icons.medication,
                              color: acc['badgeColor'] as Color? ?? BaustColors.primaryNavy,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        acc['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (acc['badgeColor'] as Color? ?? BaustColors.primaryNavy).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        acc['roleDisplay'] ?? role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: acc['badgeColor'] as Color? ?? BaustColors.primaryNavy,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Test Tool',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasEmail) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (hasPhone) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 11,
                                        color: isDoctor
                                            ? BaustColors.emergencyRed
                                            : isStudent
                                                ? BaustColors.primaryArmyGreen
                                                : BaustColors.primaryNavy,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          phone,
                                          style: TextStyle(
                                            color: isDoctor
                                                ? BaustColors.emergencyRed
                                                : isStudent
                                                    ? BaustColors.primaryArmyGreen
                                                    : BaustColors.primaryNavy,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (!hasEmail && !hasPhone) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'No email on record',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (acc['studentRoll'] != null)
                                  Text(
                                    'Student ID: ${acc['studentRoll']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: BaustColors.primaryArmyGreen),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (acc['hall'] != null)
                                  Text(
                                    '${acc['hall']} • Room ${acc['room']}',
                                    style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: BaustColors.successGreen),
                              const SizedBox(width: 4),
                              Text(
                                acc['status'] ?? 'Verified',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BaustColors.successGreen),
                              ),
                            ],
                          ),
                          if (isDoctor)
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.open_in_new, size: 14, color: BaustColors.emergencyRed),
                              label: const Text('Doctor Portal', style: TextStyle(fontSize: 11, color: BaustColors.emergencyRed)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
                              ),
                            )
                          else if (isPharmacy)
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.open_in_new, size: 14, color: BaustColors.primaryArmyGreen),
                              label: const Text('Inventory', style: TextStyle(fontSize: 11, color: BaustColors.primaryArmyGreen)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PharmacistInventoryScreen()),
                              ),
                            )
                          else if (isStudent)
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.notification_add, size: 14, color: BaustColors.emergencyRed),
                              label: const Text('Test SOS (Test Tool)', style: TextStyle(fontSize: 11, color: BaustColors.emergencyRed)),
                              onPressed: _simulateStudentSos,
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
    );
  }

  Widget _buildFacultyDirectorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FACULTY & PERSONNEL DIRECTORY (${_filteredFaculty().length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: BaustColors.textMuted,
              ),
            ),
            TextButton.icon(
              onPressed: _openAddFacultyModal,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Provision Personnel', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: BaustColors.primaryNavy),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Category Filter Chips for Faculty
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              'All',
              'BAUST Medical Center',
              'Central Administration',
              'Academic Departments',
            ].map((category) {
              final isSelected = _selectedFilter == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  showCheckmark: false,
                  label: Text(
                    category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BaustColors.textDark,
                    ),
                  ),
                  selectedColor: category == 'BAUST Medical Center'
                      ? BaustColors.emergencyRed
                      : BaustColors.primaryNavy,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.grey.shade300,
                  ),
                  onSelected: (_) => setState(() => _selectedFilter = category),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredFaculty().length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final faculty = _filteredFaculty()[index];
            final isMedical = faculty['department'] == 'BAUST Medical Center';

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: isMedical
                    ? BorderSide(color: Colors.red.shade200, width: 1.2)
                    : BorderSide.none,
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
                          backgroundColor: isMedical
                              ? Colors.red.shade50
                              : BaustColors.primaryNavy.withValues(alpha: 0.1),
                          child: Icon(
                            isMedical ? Icons.medical_services : Icons.person,
                            color: isMedical ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                faculty['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (faculty['email'] != null && faculty['email']!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  faculty['email']!,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (faculty['phone'] != null && faculty['phone']!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 11,
                                      color: isMedical ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        faculty['phone']!,
                                        style: TextStyle(
                                          color: isMedical ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMedical
                                ? Colors.red.shade50
                                : BaustColors.primaryNavy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            faculty['accessLevel'] ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isMedical ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        Icon(
                          isMedical ? Icons.badge_outlined : Icons.workspace_premium,
                          size: 15,
                          color: isMedical ? BaustColors.emergencyRed : BaustColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          faculty['designation']!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Icon(
                          isMedical ? Icons.local_hospital_outlined : Icons.school,
                          size: 15,
                          color: isMedical ? BaustColors.emergencyRed : BaustColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            faculty['department']!.split('(').first.trim(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isMedical ? BaustColors.emergencyRed : BaustColors.textMuted,
                              fontWeight: isMedical ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
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
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingAccountsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pending_actions, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                'PENDING ACCOUNTS (STAFF APPROVAL)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Review personal/external accounts awaiting administrative verification. Approve as Doctor, Pharmacist, Nurse, or Reject.',
            style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
              try {
                stream = FirebaseFirestore.instance
                    .collection('users')
                    .where('verificationStatus', isEqualTo: 'pending')
                    .snapshots();
              } catch (_) {
                stream = null;
              }

              if (stream == null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No pending accounts awaiting approval.',
                      style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                    ),
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No pending accounts awaiting approval.',
                      style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final uid = doc.id;
                  final name = data['displayName'] ?? 'Pending User';
                  final email = data['email'] ?? 'Not found - confirm with patient';
                  final createdAt = data['createdAt'];
                  String createdStr = 'Not found - confirm with patient';
                  if (createdAt is Timestamp) {
                    final d = createdAt.toDate();
                    createdStr = '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Pending',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Email: $email',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Created: $createdStr',
                          style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BaustColors.emergencyRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.medical_services_outlined, size: 14),
                              label: const Text('Approve as Doctor'),
                              onPressed: () => _updateAccountRole(uid, 'doctor', true),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BaustColors.primaryArmyGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.medication_outlined, size: 14),
                              label: const Text('Approve as Pharmacist'),
                              onPressed: () => _updateAccountRole(uid, 'pharmacist', true),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.healing_outlined, size: 14),
                              label: const Text('Approve as Nurse'),
                              onPressed: () => _updateAccountRole(uid, 'nurse', true),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.close, size: 14),
                              label: const Text('Reject'),
                              onPressed: () => _rejectAccount(uid),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    ],
  ),
);
  }

  Future<void> _updateAccountRole(String uid, String role, bool approved) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'role': role,
        'approved': approved,
        'verificationStatus': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.successGreen,
            content: Text('Account approved as ${role.toUpperCase()} successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            content: Text('Failed to update account: $e'),
          ),
        );
      }
    }
  }

  Future<void> _rejectAccount(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'verificationStatus': 'rejected',
        'approved': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Account rejected.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            content: Text('Failed to reject account: $e'),
          ),
        );
      }
    }
  }

  Widget _buildAccessLogsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BaustColors.primaryNavy.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: BaustColors.primaryNavy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.history_edu_outlined, color: BaustColors.primaryNavy, size: 20),
              SizedBox(width: 8),
              Text(
                'MEDICAL RECORD ACCESS LOGS (AUDIT TRAIL)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: BaustColors.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Compliance audit log of medical staff accessing student medical histories and dossiers.',
            style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
              try {
                stream = FirebaseFirestore.instance
                    .collection('access_logs')
                    .orderBy('createdAt', descending: true)
                    .snapshots();
              } catch (_) {
                stream = null;
              }

              if (stream == null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No access logs recorded yet.',
                      style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                    ),
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No access logs recorded yet.',
                          style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                        ),
                      ),
                    );
                  }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final doctorName = data['doctorName'] ?? 'Doctor (${data['doctorUid'] ?? "Unknown"})';
                  final studentId = data['studentId'] ?? 'Student (${data['studentUid'] ?? "Unknown"})';
                  final action = data['action'] ?? 'view_history';
                  final createdAt = data['createdAt'];
                  String timeStr = 'Not found - confirm with patient';
                  if (createdAt is Timestamp) {
                    final d = createdAt.toDate();
                    timeStr = '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
                  }

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: BaustColors.primaryNavy.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.security, size: 16, color: BaustColors.primaryNavy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$doctorName viewed patient $studentId',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Action: $action • Timestamp: $timeStr',
                              style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    ],
  ),
);
  }
}

