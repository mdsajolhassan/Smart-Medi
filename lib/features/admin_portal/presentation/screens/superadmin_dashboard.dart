import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/auth_config.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/smart_medi_drawer.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';

class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  // Faculty records are loaded live from Firestore (no hard-coded people).
  final List<Map<String, String?>> _provisionedFaculty = [];
  String _selectedFilter = 'All';

  // Registered System Accounts & Testing Overview
  String _accountFilter = 'All Accounts';
  String _accountSearchQuery = '';
  final TextEditingController _accountSearchController = TextEditingController();

  // Accounts are loaded live from Firestore (no hard-coded people).
  late final List<Map<String, dynamic>> _systemAccounts;

  @override
  void initState() {
    super.initState();
    _systemAccounts = [];

    _listenToFaculty();
  }

  @override
  void dispose() {
    _facultySubscription?.cancel();
    _accountSearchController.dispose();
    super.dispose();
  }

  bool _isProvisioningFaculty = false;
  StreamSubscription? _facultySubscription;

  void _listenToFaculty() {
    try {
      _facultySubscription = FirebaseFirestore.instance
          .collection(FirestoreCollections.faculty)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted) return;

              final List<Map<String, String?>> liveFaculty = [];
              final List<Map<String, dynamic>> liveAccounts = [];

              for (final doc in snapshot.docs) {
                final data = doc.data();
                final facultyMap = <String, String?>{
                  'name': data['name']?.toString() ?? 'Unknown Faculty',
                  'designation': data['designation']?.toString() ?? 'Faculty Member',
                  'department': data['department']?.toString() ?? 'General',
                  'email': data['email']?.toString(),
                  'phone': data['phone']?.toString(),
                  'accessLevel': data['accessLevel']?.toString() ?? 'Faculty',
                  'role': data['role']?.toString() ?? 'staff',
                  'docId': doc.id,
                };
                liveFaculty.add(facultyMap);

                final isMedical =
                    (data['department']?.toString() == 'BAUST Medical Center') ||
                    (data['role'] == 'doctor' || data['role'] == 'pharmacist' || data['role'] == 'nurse');

                liveAccounts.add({
                  'name': data['name'] ?? 'Faculty Member',
                  'email': data['email'],
                  'phone': data['phone'],
                  'role': data['role'] ?? 'staff',
                  'roleDisplay': data['designation'] ?? 'Faculty Member',
                  'department': data['department'] ?? 'Academic Wing',
                  'designation': data['designation'] ?? 'Faculty',
                  'status': 'Verified & Active Personnel',
                  'isSuperAdmin': false,
                  'badgeColor': isMedical ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                });
              }

              setState(() {
                for (final f in liveFaculty) {
                  final exists = _provisionedFaculty.any(
                    (e) => (f['email'] != null && e['email'] == f['email']) || e['name'] == f['name'],
                  );
                  if (!exists) {
                    _provisionedFaculty.insert(0, f);
                  }
                }

                for (final a in liveAccounts) {
                  final exists = _systemAccounts.any(
                    (e) => (a['email'] != null && e['email'] == a['email']) || e['name'] == a['name'],
                  );
                  if (!exists) {
                    _systemAccounts.add(a);
                  }
                }
              });
            },
            onError: (e) {
              debugPrint('[SuperAdmin] Notice loading faculty from Firestore: $e');
            },
          );
    } catch (e) {
      debugPrint('[SuperAdmin] Error attaching faculty listener: $e');
    }
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
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
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BaustColors.primaryNavy),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
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
                      labelText: 'Institutional / Contact Email',
                      hintText: 'faculty@baust.edu.bd',
                      prefixIcon: Icon(Icons.email_outlined, color: BaustColors.primaryNavy),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email address is required';
                      }
                      final clean = v.trim().toLowerCase();
                      if (!clean.contains('@') || !clean.contains('.')) {
                        return 'Enter a valid email address (e.g. name@domain.com)';
                      }
                      return null;
                    },
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
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, style: const TextStyle(fontSize: 13)),
                          ),
                        )
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
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, style: const TextStyle(fontSize: 13)),
                          ),
                        )
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
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, style: const TextStyle(fontSize: 13)),
                          ),
                        )
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
                    icon: _isProvisioningFaculty
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.how_to_reg),
                    label: Text(
                      _isProvisioningFaculty ? 'Provisioning...' : 'Provision & Assign Role',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isProvisioningFaculty
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              setModalState(() => _isProvisioningFaculty = true);

                              final messenger = ScaffoldMessenger.of(context);
                              final email = emailController.text.trim().toLowerCase();
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim().isEmpty ? null : phoneController.text.trim();

                              String resolvedRole = 'staff';
                              final roleLower = selectedRole.toLowerCase();
                              if (roleLower.contains('doctor') || roleLower.contains('medical chief')) {
                                resolvedRole = 'doctor';
                              } else if (roleLower.contains('pharmacist') || roleLower.contains('medical assistant')) {
                                resolvedRole = 'pharmacist';
                              } else if (roleLower.contains('nurse')) {
                                resolvedRole = 'nurse';
                              }

                              final newFaculty = <String, String?>{
                                'name': name,
                                'designation': selectedDesignation,
                                'department': selectedDept,
                                'email': email,
                                'phone': phone,
                                'accessLevel': selectedRole,
                                'role': resolvedRole,
                              };

                              try {
                                // Save to Firestore faculty collection
                                await FirebaseFirestore.instance.collection(FirestoreCollections.faculty).add({
                                  ...newFaculty,
                                  'provisionedAt': FieldValue.serverTimestamp(),
                                  'provisionedBy': AuthConfig.superAdminEmail,
                                  'status': 'active',
                                });

                                // Also ensure any existing user document is upgraded with this role
                                try {
                                  final usersByEmail = await FirebaseFirestore.instance
                                      .collection(FirestoreCollections.users)
                                      .where('email', isEqualTo: email)
                                      .limit(1)
                                      .get();
                                  if (usersByEmail.docs.isNotEmpty) {
                                    await usersByEmail.docs.first.reference.update({
                                      'role': resolvedRole,
                                      'designation': selectedDesignation,
                                      'department': selectedDept,
                                      'accessLevel': selectedRole,
                                      'approved': true,
                                      'verificationStatus': 'verified',
                                    });
                                  }
                                } catch (_) {}

                                setState(() {
                                  _provisionedFaculty.insert(0, newFaculty);
                                  _systemAccounts.add({
                                    'name': name,
                                    'email': email,
                                    'phone': phone,
                                    'role': resolvedRole,
                                    'roleDisplay': selectedDesignation,
                                    'department': selectedDept,
                                    'designation': selectedDesignation,
                                    'status': 'Verified & Active Personnel',
                                    'isSuperAdmin': false,
                                    'badgeColor': (resolvedRole == 'doctor' || resolvedRole == 'pharmacist')
                                        ? BaustColors.emergencyRed
                                        : BaustColors.primaryNavy,
                                  });
                                });

                                if (ctx.mounted) Navigator.pop(ctx);

                                messenger.clearSnackBars();
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: BaustColors.successGreen,
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('✅ Successfully provisioned $name as $selectedRole!')),
                                      ],
                                    ),
                                  ),
                                );
                              } catch (e) {
                                // Fallback: still add locally
                                setState(() {
                                  _provisionedFaculty.insert(0, newFaculty);
                                  _systemAccounts.add({
                                    'name': name,
                                    'email': email,
                                    'phone': phone,
                                    'role': resolvedRole,
                                    'roleDisplay': selectedDesignation,
                                    'department': selectedDept,
                                    'designation': selectedDesignation,
                                    'status': 'Locally Provisioned',
                                    'isSuperAdmin': false,
                                    'badgeColor': BaustColors.primaryNavy,
                                  });
                                });

                                if (ctx.mounted) Navigator.pop(ctx);

                                messenger.clearSnackBars();
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.orange.shade800,
                                    content: Row(
                                      children: [
                                        const Icon(Icons.cloud_off, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('⚠️ Provisioned locally ($name). Cloud notice: $e')),
                                      ],
                                    ),
                                  ),
                                );
                              } finally {
                                _isProvisioningFaculty = false;
                              }
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
        return f['department'] == 'Central Administration' || f['department'] == 'Examination Wing';
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

      final matchesFilter =
          _accountFilter == 'All Accounts' ||
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

      final matchesSearch =
          q.isEmpty ||
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
            const Flexible(child: Text('SuperAdmin — System Hierarchy', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
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
                          user?.displayName ?? 'Super Admin',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                  count:
                      '${_systemAccounts.where((a) => a['role'] == 'doctor' || a['role'] == 'pharmacist' || a['role'] == 'nurse').length}',
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

            const SizedBox(height: 20),

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
            children: ['All Accounts', 'Students', 'Doctors', 'Pharmacists & Nurses', 'SuperAdmin'].map((cat) {
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
              child: Text(
                'No system accounts match the query.',
                style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
              ),
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
                            backgroundColor: (acc['badgeColor'] as Color? ?? BaustColors.primaryNavy).withValues(
                              alpha: 0.12,
                            ),
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
                                        color: (acc['badgeColor'] as Color? ?? BaustColors.primaryNavy).withValues(
                                          alpha: 0.1,
                                        ),
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
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (acc['studentRoll'] != null)
                                  Text(
                                    'Student ID: ${acc['studentRoll']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: BaustColors.primaryArmyGreen,
                                    ),
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: BaustColors.successGreen,
                                ),
                              ),
                            ],
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
            children: ['All', 'BAUST Medical Center', 'Central Administration', 'Academic Departments'].map((category) {
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
                  side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
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
                side: isMedical ? BorderSide(color: Colors.red.shade200, width: 1.2) : BorderSide.none,
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
                            color: isMedical ? Colors.red.shade50 : BaustColors.primaryNavy.withValues(alpha: 0.1),
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

  Widget _buildStatCard({required String title, required String count, required IconData icon, required Color color}) {
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
            Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: BaustColors.textMuted)),
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
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
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
                      child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
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
          SnackBar(backgroundColor: BaustColors.emergencyRed, content: Text('Failed to update account: $e')),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text('Account rejected.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: BaustColors.emergencyRed, content: Text('Failed to reject account: $e')),
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
          BoxShadow(color: BaustColors.primaryNavy.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
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
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
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
                      child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
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
