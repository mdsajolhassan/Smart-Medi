import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/smart_medi_drawer.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  // Comprehensive student dataset across BAUST departments and cohorts
  final List<Map<String, dynamic>> _allUniversityStudents = [];

  late String _activeHierarchyTier;
  String _departmentFilter = 'All Departments';
  String _batchFilter = 'All Batches';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeHierarchyTier = 'Head of Department';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ref.read(authControllerProvider).userProfile;
    if (user != null && user.accessLevel != null) {
      final role = user.accessLevel!;
      if (role.contains('VC') || role.contains('Vice Chancellor') || role.contains('Proctor')) {
        _activeHierarchyTier = 'VC / Proctor';
      } else if (role.contains('Head')) {
        _activeHierarchyTier = 'Head of Department';
      } else if (role.contains('Coordinator')) {
        _activeHierarchyTier = 'Batch Coordinator';
      } else {
        _activeHierarchyTier = 'Advisor';
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredStudents(UserProfile? user) {
    final staffDept = user?.department ?? 'Computer Science & Engineering (CSE)';
    final staffName = user?.displayName ?? 'Dr. Md Nakib Hayat Chowdhury';

    List<Map<String, dynamic>> results = List.from(_allUniversityStudents);

    // 1. Hierarchical Access Scope Filtering
    switch (_activeHierarchyTier) {
      case 'VC / Proctor':
        // University-wide: All students accessible, can filter by department
        if (_departmentFilter != 'All Departments') {
          results = results.where((s) => s['department'] == _departmentFilter).toList();
        }
        break;

      case 'Head of Department':
        // Department View: Strictly limited to the Head's department
        results = results.where((s) => s['department'] == staffDept).toList();
        if (_batchFilter != 'All Batches') {
          results = results.where((s) => s['batch'] == _batchFilter).toList();
        }
        break;

      case 'Batch Coordinator':
        // Batch View: Limited to Coordinator's department and batch
        results = results
            .where((s) => s['department'] == staffDept && s['batch'] == '11th Batch')
            .toList();
        break;

      case 'Advisor':
      default:
        // Advisor View: Strictly assigned students
        results = results.where((s) {
          final advisorName = (s['advisor'] ?? '') as String;
          return advisorName.toLowerCase().contains(staffName.toLowerCase()) ||
              staffName.toLowerCase().contains(advisorName.toLowerCase());
        }).toList();
        break;
    }

    // 2. Search Query Filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      results = results.where((s) {
        final name = (s['name'] as String).toLowerCase();
        final roll = (s['roll'] as String).toLowerCase();
        final hall = (s['hall'] as String).toLowerCase();
        return name.contains(query) || roll.contains(query) || hall.contains(query);
      }).toList();
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;
    final filteredList = _getFilteredStudents(user);

    final emergencyCount = filteredList.where((s) => s['hasEmergency'] == true).length;
    final criticalFlagCount =
        filteredList.where((s) => (s['flags'] as List).isNotEmpty).length;

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
                'Faculty & Advisor Portal',
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Faculty Profile Summary Header Card
            _buildFacultyProfileHeader(user),

            const SizedBox(height: 16),

            // Dynamic Hierarchy Tier Switcher (Interactive for testing all 4 roles)
            _buildHierarchyScopeBanner(),

            const SizedBox(height: 16),

            // Metrics Summary Row
            _buildMetricsRow(
              totalCount: filteredList.length,
              emergencyCount: emergencyCount,
              criticalCount: criticalFlagCount,
            ),

            const SizedBox(height: 16),

            // Search and Tier-Specific Filter Controls
            _buildFiltersCard(),

            const SizedBox(height: 16),

            // Student Roster Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVE COHORT STUDENTS (${filteredList.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: BaustColors.textMuted,
                  ),
                ),
                Text(
                  _activeHierarchyTier,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: BaustColors.primaryNavy,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Student Cards List
            if (filteredList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: BaustColors.textMuted),
                    SizedBox(height: 8),
                    Text(
                      'No students assigned yet.',
                      style: TextStyle(color: BaustColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildStudentCard(filteredList[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyProfileHeader(UserProfile? user) {
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
            radius: 28,
            backgroundColor: BaustColors.primaryNavy.withValues(alpha: 0.1),
            child: const Icon(Icons.person_pin, size: 34, color: BaustColors.primaryNavy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Dr. Md Nakib Hayat Chowdhury',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: BaustColors.textDark,
                  ),
                ),
                Text(
                  '${user?.designation ?? "Head of Department, CSE"} • ${user?.department ?? "Computer Science & Engineering (CSE)"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email != null && user!.email.isNotEmpty
                      ? 'Official Email: ${user.email}'
                      : 'Official Email: Not found - confirm with patient',
                  style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyScopeBanner() {
    final isExecutive = _activeHierarchyTier == 'VC / Proctor';
    final isHead = _activeHierarchyTier == 'Head of Department';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExecutive
              ? [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)]
              : isHead
                  ? [const Color(0xFF0F766E), const Color(0xFF115E59)]
                  : [const Color(0xFF1E293B), const Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isExecutive ? Icons.military_tech : Icons.security,
                    color: Colors.amberAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Active RBAC Governance Tier:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Interactive Tier Selector Dropdown (Allows demo testing all 4 roles)
              DropdownButton<String>(
                value: _activeHierarchyTier,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.amberAccent),
                items: const [
                  DropdownMenuItem(value: 'VC / Proctor', child: Text('VC / Proctor (University)')),
                  DropdownMenuItem(value: 'Head of Department', child: Text('Head of Department')),
                  DropdownMenuItem(value: 'Batch Coordinator', child: Text('Batch Coordinator')),
                  DropdownMenuItem(value: 'Advisor', child: Text('Advisor (Guide Teacher)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _activeHierarchyTier = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _getScopeDescription(),
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  String _getScopeDescription() {
    switch (_activeHierarchyTier) {
      case 'VC / Proctor':
        return 'University-Wide Authority: Full visibility across all faculties, residential halls, and critical health incidents.';
      case 'Head of Department':
        return 'Department Leadership: Aggregated clinical data across all batches within your engineering department.';
      case 'Batch Coordinator':
        return 'Batch Cohort Scope: Focused on your assigned academic batch (11th Batch) with mentor assignment breakdown.';
      case 'Advisor':
      default:
        return 'Guide Advisor Scope: Medical profiles and emergency alerts isolated strictly to your assigned advisees.';
    }
  }

  Widget _buildMetricsRow({
    required int totalCount,
    required int emergencyCount,
    required int criticalCount,
  }) {
    return Row(
      children: [
        _buildMetricTile('Cohort Total', '$totalCount', BaustColors.primaryNavy, Icons.school),
        const SizedBox(width: 10),
        _buildMetricTile(
          'Active SOS',
          '$emergencyCount',
          emergencyCount > 0 ? BaustColors.emergencyRed : Colors.grey,
          Icons.emergency_share,
        ),
        const SizedBox(width: 10),
        _buildMetricTile('Critical Flags', '$criticalCount', Colors.amber.shade800, Icons.flag),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: BaustColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Search Input
          TextField(
            decoration: InputDecoration(
              hintText: 'Search student name, roll, or hall...',
              prefixIcon: const Icon(Icons.search, color: BaustColors.primaryNavy),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),

          // Department selector for VC/Proctor tier
          if (_activeHierarchyTier == 'VC / Proctor') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _departmentFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by Department',
                prefixIcon: Icon(Icons.filter_alt_outlined, color: BaustColors.primaryNavy),
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              items: [
                'All Departments',
                ...BaustDepartments.departments,
              ].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _departmentFilter = val);
              },
            ),
          ],

          // Batch selector for Head of Dept tier
          if (_activeHierarchyTier == 'Head of Department') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _batchFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by Academic Batch',
                prefixIcon: Icon(Icons.calendar_today_outlined, color: BaustColors.primaryNavy),
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'All Batches', child: Text('All Department Batches')),
                DropdownMenuItem(value: '10th Batch', child: Text('10th Batch (Senior)')),
                DropdownMenuItem(value: '11th Batch', child: Text('11th Batch (Junior)')),
                DropdownMenuItem(value: '12th Batch', child: Text('12th Batch (Freshmen)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _batchFilter = val);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final hasEmergency = student['hasEmergency'] == true;
    final flags = student['flags'] as List;

    return Card(
      elevation: hasEmergency ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasEmergency ? BaustColors.emergencyRed : Colors.transparent,
          width: hasEmergency ? 2 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasEmergency
                      ? Colors.red.shade100
                      : BaustColors.primaryNavy.withValues(alpha: 0.1),
                  child: Icon(
                    hasEmergency ? Icons.notification_important : Icons.person,
                    color: hasEmergency ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            student['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (hasEmergency) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BaustColors.emergencyRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ACTIVE SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Roll: ${student['roll']} • ${student['batch']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                    student['blood'],
                    style: const TextStyle(
                      color: BaustColors.emergencyRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                const Icon(Icons.apartment, size: 15, color: BaustColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${student['hall']}, Room ${student['room']}',
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                const Icon(Icons.co_present, size: 15, color: BaustColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Advisor: ${student['advisor']}',
                  style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                ),
              ],
            ),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: flags.map((flag) {
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
            ],
          ],
        ),
      ),
    );
  }
}
