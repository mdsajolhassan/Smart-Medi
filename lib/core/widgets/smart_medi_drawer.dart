import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/auth_config.dart';
import '../constants/baust_constants.dart';
import '../../features/advisor_portal/presentation/screens/staff_dashboard_screen.dart';
import '../../features/auth_rbac/presentation/controllers/auth_controller.dart';
import '../../features/blood_bank/presentation/screens/blood_donor_directory.dart';
import '../../features/dashboard/presentation/screens/main_dashboard_screen.dart';
import '../../features/medical_operations/presentation/screens/doctor_dashboard_screen.dart';
import '../../features/medical_operations/presentation/screens/patient_checkin_log_screen.dart';
import '../../features/medical_operations/presentation/screens/patient_lookup_screen.dart';
import '../../features/medical_operations/presentation/screens/pharmacist_inventory_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/admin_portal/presentation/screens/id_verification_review_screen.dart';
import '../../features/admin_portal/presentation/screens/admin_console_screen.dart';
import '../../features/admin_portal/presentation/screens/feedback_screens.dart';
import '../../features/admin_portal/presentation/screens/user_management_screen.dart';

/// Unified Side Drawer providing enterprise-grade navigation, profile summary,
/// and role-aware operational routing across all Smart Medi dashboards.
class SmartMediDrawer extends ConsumerWidget {
  final String? activeRoute;

  const SmartMediDrawer({super.key, this.activeRoute});

  String _formatRoleDisplay(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
      case 'medical_officer':
        return 'Medical Officer / Doctor';
      case 'pharmacist':
        return 'Pharmacist';
      case 'medical_assistant':
      case 'nurse':
        return 'Medical Assistant / Nurse';
      case 'superadmin':
      case 'admin':
        return 'Super Administrator';
      case 'staff':
      case 'faculty':
        return 'Faculty / Advisor';
      case 'student':
      default:
        return 'Student';
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
      case 'medical_officer':
        return const Color(0xFF0284C7); // Sky blue
      case 'pharmacist':
        return const Color(0xFF0D9488); // Teal
      case 'superadmin':
      case 'admin':
        return const Color(0xFFD97706); // Amber
      case 'staff':
      case 'faculty':
        return const Color(0xFF4F46E5); // Indigo
      case 'student':
      default:
        return BaustColors.primaryArmyGreen;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;
    final role = user?.role.toLowerCase() ?? 'student';
    final isSuperAdmin = user?.isSuperAdmin == true || AuthConfig.isSuperAdminEmail(user?.email ?? '');
    final isAdmin = isSuperAdmin || user?.isAdmin == true;

    final roleColor = _getRoleColor(role);
    final displayName = user?.displayName;
    final initial = (displayName != null && displayName.isNotEmpty) ? displayName[0].toUpperCase() : 'U';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ==========================================
            // DRAWER HEADER (PRO PROFILE CARD)
            // ==========================================
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 20, right: 20, bottom: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [BaustColors.armyGreenDark, BaustColors.primaryArmyGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: BaustColors.primaryArmyGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'Smart Medi User',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user?.studentRoll != null && user!.studentRoll!.isNotEmpty
                                  ? 'ID: ${user.studentRoll}'
                                  : (user?.email ?? 'user@baust.edu.bd'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Role & Verification Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatRoleDisplay(role),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (user?.verificationStatus == 'verified' || isSuperAdmin)
                              ? Colors.green.shade700
                              : Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (user?.verificationStatus == 'verified' || isSuperAdmin)
                                  ? Icons.verified
                                  : Icons.hourglass_top,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (user?.verificationStatus == 'verified' || isSuperAdmin)
                                  ? 'Verified'
                                  : 'Pending Approval',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==========================================
            // DRAWER NAVIGATION ITEMS
            // ==========================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _buildSectionLabel('OPERATIONAL NAVIGATION'),

                  // 1. Role-Specific Primary Dashboard
                  if (role == 'doctor' ||
                      role == 'medical_officer' ||
                      role == 'medical_assistant' ||
                      role == 'nurse') ...[
                    _buildNavTile(
                      context,
                      icon: Icons.local_hospital_outlined,
                      title: 'Doctor Portal (SOS & Queue)',
                      subtitle: 'Clinical consultations & active alerts',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
                        );
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.person_search_outlined,
                      title: 'Student Directory & Search',
                      subtitle: 'Browse by department or lookup ID',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientLookupScreen()));
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.assignment_ind_outlined,
                      title: 'Patient Check-In Log',
                      subtitle: 'Physical clinic walk-ins & tracker',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()));
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.medication_outlined,
                      title: 'Pharmacy Inventory',
                      subtitle: 'Medicine stock & multiplier dispense',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacistInventoryScreen()));
                      },
                    ),
                  ] else if (role == 'pharmacist') ...[
                    _buildNavTile(
                      context,
                      icon: Icons.medication_outlined,
                      title: 'Pharmacy Inventory',
                      subtitle: 'Essential SKU stock & dispense',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const PharmacistInventoryScreen()),
                        );
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.assignment_ind_outlined,
                      title: 'Patient Check-In Log',
                      subtitle: 'Daily clinic visit roster',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientCheckInLogScreen()));
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.medical_services_outlined,
                      title: 'Doctor Portal / SOS Monitor',
                      subtitle: 'View live emergency consultations',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()));
                      },
                    ),
                  ] else if (role == 'staff' || role == 'faculty') ...[
                    _buildNavTile(
                      context,
                      icon: Icons.school_outlined,
                      title: 'Faculty & Advisor Portal',
                      subtitle: 'Department student cohorts & emergencies',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const StaffDashboardScreen()),
                        );
                      },
                    ),
                  ] else ...[
                    // Student Default
                    _buildNavTile(
                      context,
                      icon: Icons.touch_app_outlined,
                      title: 'Emergency SOS & Home',
                      subtitle: 'One-tap critical ambulance dispatch',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MainDashboardScreen(initialTabIndex: 0)),
                        );
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.medical_information_outlined,
                      title: 'My Medical History',
                      subtitle: 'AI-extracted clinical records & timeline',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MainDashboardScreen(initialTabIndex: 3)),
                        );
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.person_outline,
                      title: 'Student Profile & Residency',
                      subtitle: 'Hall, room & emergency contacts',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MainDashboardScreen(initialTabIndex: 1)),
                        );
                      },
                    ),
                  ],

                  // Common Campus Utilities
                  _buildNavTile(
                    context,
                    icon: Icons.manage_accounts_outlined,
                    title: 'Edit My Profile',
                    subtitle: 'Update personal & role details',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Campus Blood Bank',
                    subtitle: 'Directory of voluntary student donors',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodDonorDirectoryScreen()));
                    },
                  ),

                  const Divider(height: 24, thickness: 1),

                  // ==========================================
                  // ADMIN / PRIVILEGED SECTION
                  // ==========================================
                  if (isAdmin) ...[
                    _buildSectionLabel(isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN'),
                    _buildNavTile(
                      context,
                      icon: Icons.space_dashboard_outlined,
                      title: isSuperAdmin ? 'Super Admin Console' : 'Admin Console',
                      subtitle: 'Overview & management',
                      titleColor: const Color(0xFFD97706),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminConsoleScreen()));
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.manage_accounts_outlined,
                      title: 'User Management',
                      subtitle: isSuperAdmin ? 'Students, doctors & admins' : 'Students & doctors',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
                      },
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.badge_outlined,
                      title: 'Student ID Verification',
                      subtitle: 'Approve new student accounts',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const IdVerificationReviewScreen()));
                      },
                    ),
                    if (isSuperAdmin)
                      _buildNavTile(
                        context,
                        icon: Icons.bug_report_outlined,
                        title: 'Feedback & Bug Reports',
                        subtitle: 'Reports from all users',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackInboxScreen()));
                        },
                      ),
                    const Divider(height: 24, thickness: 1),
                  ],

                  // ==========================================
                  // SESSION & LOGOUT
                  // ==========================================
                  if (!isSuperAdmin)
                    _buildNavTile(
                      context,
                      icon: Icons.feedback_outlined,
                      title: 'Feedback / Report a Bug',
                      subtitle: 'Tell the Smart Medi team',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SendFeedbackScreen()));
                      },
                    ),
                  _buildSectionLabel('SESSION'),
                  _buildNavTile(
                    context,
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    titleColor: BaustColors.emergencyRed,
                    iconColor: BaustColors.emergencyRed,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(authControllerProvider.notifier).signOut();
                    },
                  ),
                ],
              ),
            ),

            // ==========================================
            // DRAWER FOOTER (BRANDING)
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                color: Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  Image.asset('assets/branding/smart_medi_icon_1024.png', height: 24, width: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Medi • BAUST Medical Center',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.textDark),
                        ),
                        Text(
                          'Military University Medical Automation',
                          style: TextStyle(fontSize: 9, color: BaustColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: BaustColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? BaustColors.primaryArmyGreen).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? BaustColors.primaryArmyGreen),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor ?? BaustColors.textDark),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
