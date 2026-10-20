import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/shimmer_loading.dart';

/// Department-Wise Student Directory widget.
/// Fetches all students from Firestore, groups them by academic department
/// (ensuring CSE is prioritized at the top), and displays an accordion-style directory.
class StudentDepartmentDirectory extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final void Function(Map<String, dynamic> studentData, String studentUid) onStudentSelected;
  final List<Map<String, dynamic>>? studentsOverride;

  const StudentDepartmentDirectory({
    super.key,
    this.firestore,
    required this.onStudentSelected,
    this.studentsOverride,
  });

  @override
  State<StudentDepartmentDirectory> createState() => _StudentDepartmentDirectoryState();
}

class _StudentDepartmentDirectoryState extends State<StudentDepartmentDirectory> {
  // Canonical academic departments list with CSE strictly at the top
  static const List<String> canonicalDepartments = [
    'Computer Science & Engineering (CSE)',
    'Electrical & Electronic Engineering (EEE)',
    'Mechanical Engineering (ME)',
    'Civil Engineering (CE)',
    'Information & Communication Technology (ICT)',
    'Industrial & Production Engineering (IPE)',
    'Business Administration (DBA)',
    'English',
  ];

  bool _isFirebaseReady() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _db {
    if (widget.firestore != null) return widget.firestore;
    if (_isFirebaseReady()) return FirebaseFirestore.instance;
    return null;
  }

  String _normalizeDepartment(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Computer Science & Engineering (CSE)';
    }
    final s = raw.trim().toLowerCase();
    if (s.contains('cse') || s.contains('computer')) {
      return 'Computer Science & Engineering (CSE)';
    }
    if (s.contains('eee') || s.contains('electrical')) {
      return 'Electrical & Electronic Engineering (EEE)';
    }
    if (s.contains('me') || s.contains('mechanical')) {
      return 'Mechanical Engineering (ME)';
    }
    if (s.contains('ce') || s.contains('civil')) {
      return 'Civil Engineering (CE)';
    }
    if (s.contains('ict')) {
      return 'Information & Communication Technology (ICT)';
    }
    if (s.contains('ipe') || s.contains('industrial')) {
      return 'Industrial & Production Engineering (IPE)';
    }
    if (s.contains('dba') || s.contains('business') || s.contains('bba')) {
      return 'Business Administration (DBA)';
    }
    if (s.contains('english')) {
      return 'English';
    }
    return raw.trim();
  }

  IconData _getDepartmentIcon(String dept) {
    final d = dept.toLowerCase();
    if (d.contains('cse') || d.contains('computer')) return Icons.computer;
    if (d.contains('eee') || d.contains('electrical')) return Icons.bolt;
    if (d.contains('me') || d.contains('mechanical')) return Icons.build;
    if (d.contains('ce') || d.contains('civil')) return Icons.apartment;
    if (d.contains('ict')) return Icons.devices;
    if (d.contains('ipe')) return Icons.precision_manufacturing;
    if (d.contains('business') || d.contains('dba')) return Icons.business_center;
    if (d.contains('english')) return Icons.menu_book;
    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    // 1. If test override provided, render directly
    if (widget.studentsOverride != null) {
      return _buildGroupedAccordions(widget.studentsOverride!);
    }

    final db = _db;
    // 2. If Firebase is uninitialized (pure unit tests without override), render fallback gracefully
    if (db == null) {
      return _buildGroupedAccordions([]);
    }

    // 3. Live Firestore stream: fetch users where role == 'student'
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').where('role', isEqualTo: 'student').snapshots(),
      builder: (context, usersSnapshot) {
        if (usersSnapshot.hasError) {
          // Fallback query to 'students' collection if users query has permission issues
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('students').snapshots(),
            builder: (ctx, studentsSnapshot) {
              if (studentsSnapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerSkeleton();
              }
              final docs = studentsSnapshot.data?.docs ?? [];
              final list = docs.map((d) {
                final data = Map<String, dynamic>.from(d.data());
                data['uid'] = data['uid'] ?? d.id;
                return data;
              }).toList();
              return _buildGroupedAccordions(list);
            },
          );
        }

        if (usersSnapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerSkeleton();
        }

        final userDocs = usersSnapshot.data?.docs ?? [];
        if (userDocs.isEmpty) {
          // Check 'students' collection as fallback
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('students').snapshots(),
            builder: (ctx, altSnapshot) {
              if (altSnapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerSkeleton();
              }
              final docs = altSnapshot.data?.docs ?? [];
              final list = docs.map((d) {
                final data = Map<String, dynamic>.from(d.data());
                data['uid'] = data['uid'] ?? d.id;
                return data;
              }).toList();
              return _buildGroupedAccordions(list);
            },
          );
        }

        final studentList = userDocs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['uid'] = data['uid'] ?? d.id;
          return data;
        }).toList();

        return _buildGroupedAccordions(studentList);
      },
    );
  }

  /// Modern Shimmer loading skeleton effect
  Widget _buildShimmerSkeleton() {
    return ShimmerLoading(
      child: Column(
        children: List.generate(4, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const ShimmerBox(width: 36, height: 36, borderRadius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 160, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 10),
                    ],
                  ),
                ),
                const ShimmerBox(width: 24, height: 24, borderRadius: 12),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Organizes students into academic departments with CSE placed first
  Widget _buildGroupedAccordions(List<Map<String, dynamic>> rawStudents) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    // Initialize canonical departments
    for (final dept in canonicalDepartments) {
      grouped[dept] = [];
    }

    // Populate students into their corresponding department
    for (final s in rawStudents) {
      final deptKey = _normalizeDepartment(s['department']?.toString());
      if (!grouped.containsKey(deptKey)) {
        grouped[deptKey] = [];
      }
      grouped[deptKey]!.add(s);
    }

    final allDepts = grouped.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: allDepts.map((department) {
        final studentsInDept = grouped[department] ?? [];
        final isCse = department.contains('CSE');
        final icon = _getDepartmentIcon(department);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCse
                  ? BaustColors.primaryArmyGreen.withValues(alpha: 0.3)
                  : Colors.grey.shade200,
              width: isCse ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
              initiallyExpanded: isCse,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCse
                      ? BaustColors.primaryArmyGreen.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isCse ? BaustColors.primaryArmyGreen : Colors.grey.shade700,
                ),
              ),
              title: Text(
                department,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCse ? BaustColors.primaryArmyGreen : BaustColors.textDark,
                ),
              ),
              subtitle: Text(
                '${studentsInDept.length} registered ${studentsInDept.length == 1 ? "student" : "students"}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              children: [
                if (studentsInDept.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 28,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'No students registered yet',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: BaustColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Students will appear here upon onboarding completion.',
                            style: TextStyle(fontSize: 10, color: BaustColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: studentsInDept.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (ctx, index) {
                      final student = studentsInDept[index];
                      final name = student['displayName']?.toString() ??
                          student['name']?.toString() ??
                          'Unknown Student';
                      final studentId = student['studentId']?.toString() ??
                          student['studentRoll']?.toString() ??
                          'N/A';
                      final bloodGroup = student['bloodGroup']?.toString();
                      final uid = student['uid']?.toString() ??
                          student['studentId']?.toString() ??
                          'student_$index';

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: BaustColors.primaryArmyGreen,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: BaustColors.textDark,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'ID: $studentId',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: BaustColors.textMuted,
                                ),
                              ),
                            ),
                            if (bloodGroup != null && bloodGroup.trim().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  bloodGroup,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 13,
                          color: BaustColors.primaryArmyGreen,
                        ),
                        onTap: () => widget.onStudentSelected(student, uid),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
    );
  }
}
