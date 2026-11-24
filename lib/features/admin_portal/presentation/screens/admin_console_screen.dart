import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../../core/widgets/smart_medi_drawer.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../../data/user_admin_service.dart';
import 'pharmacy_stock_alerts_screen.dart';
import 'custom_medicine_requests_screen.dart';
import 'feedback_screens.dart';
import 'id_verification_review_screen.dart';
import 'superadmin_dashboard.dart';
import 'user_management_screen.dart';
import '../../../../core/widgets/animations.dart';

/// Home screen for the Admin and Super Admin roles.
class AdminConsoleScreen extends ConsumerStatefulWidget {
  final Stream<List<Map<String, dynamic>>> Function()? usersStreamOverride;
  const AdminConsoleScreen({super.key, this.usersStreamOverride});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  Stream<List<Map<String, dynamic>>>? _users;

  @override
  void initState() {
    super.initState();
    try {
      _users = widget.usersStreamOverride?.call() ?? UserAdminService().watchUsers();
    } catch (_) {
      _users = null; // Firebase not available (e.g. tests) — hide live stats
    }
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).userProfile;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isSuper = user.isSuperAdmin;
    final gutter = Breakpoints.gutter(context);

    final actions = <_ConsoleAction>[
      _ConsoleAction(
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFF7C3AED),
        title: 'User Management',
        subtitle: isSuper ? 'Add or remove students, doctors and admins' : 'Add or remove students and doctors',
        onTap: () => _open(const UserManagementScreen()),
      ),
      _ConsoleAction(
        icon: Icons.badge_rounded,
        color: const Color(0xFF0EA5E9),
        title: 'Student ID Verification',
        subtitle: 'Approve new student accounts',
        onTap: () => _open(const IdVerificationReviewScreen()),
      ),
      _ConsoleAction(
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFF0D9488),
        title: 'Pharmacy Stock Alerts',
        subtitle: 'Low stock & expiry; notify the pharmacist',
        onTap: () => _open(const PharmacyStockAlertsScreen()),
      ),
      _ConsoleAction(
        icon: Icons.local_pharmacy_rounded,
        color: const Color(0xFF16A34A),
        title: 'Custom Medicine Requests',
        subtitle: 'Medicines doctors prescribed that the pharmacy does not stock',
        onTap: () => _open(const CustomMedicineRequestsScreen()),
      ),
      if (isSuper)
        _ConsoleAction(
          icon: Icons.bug_report_rounded,
          color: const Color(0xFFE11D48),
          title: 'Feedback & Bug Reports',
          subtitle: 'Read and resolve reports from all users',
          onTap: () => _open(const FeedbackInboxScreen()),
        ),
      if (isSuper)
        _ConsoleAction(
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFFF59E0B),
          title: 'Control Center',
          subtitle: 'Faculty directory and access logs',
          onTap: () => _open(const SuperAdminDashboard()),
        ),
      _ConsoleAction(
        icon: Icons.person_rounded,
        color: const Color(0xFF10B981),
        title: 'My Profile',
        subtitle: 'Update your own details',
        onTap: () => _open(const EditProfileScreen()),
      ),
      if (!isSuper)
        _ConsoleAction(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF64748B),
          title: 'Send Feedback',
          subtitle: 'Report a bug to the super admin',
          onTap: () => _open(const SendFeedbackScreen()),
        ),
    ];

    return Scaffold(
      drawer: const SmartMediDrawer(),
      appBar: AppBar(title: Text(isSuper ? 'Super Admin Console' : 'Admin Console')),
      body: ResponsiveCenter(
        maxWidth: 1200,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 32),
          children: [
            _hero(user, isSuper),
            const SizedBox(height: 20),
            if (_users != null) _stats(),
            const SizedBox(height: 20),
            const Text('Manage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ResponsiveWrapGrid(
              minTileWidth: 300,
              children: [
                for (var i = 0; i < actions.length; i++)
                  FadeSlideIn(
                    index: i,
                    child: HoverLift(child: _actionCard(actions[i])),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_moon_outlined, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Privacy: admins manage roles and access only. Passwords are never visible, and admins cannot open '
                      'another user\'s dashboard or medical records.',
                      style: TextStyle(fontSize: 12.5),
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

  Widget _hero(UserProfile user, bool isSuper) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              isSuper ? Icons.workspace_premium_rounded : Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.displayName.split(' ').first}',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isSuper ? 'Super Admin • full account control' : 'Admin • student & doctor accounts',
                  style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _users,
      builder: (context, snap) {
        final all = snap.data ?? const [];
        final active = all.where((u) => u['accountStatus'] != 'removed').toList();
        int n(bool Function(Map<String, dynamic>) f) => active.where(f).length;
        final tiles = [
          ('Students', n((u) => u['role'] == 'student'), Icons.school_rounded, const Color(0xFF0EA5E9)),
          (
            'Doctors',
            n(
              (u) =>
                  const {'doctor', 'medical_officer', 'medical_assistant', 'nurse', 'pharmacist'}.contains(u['role']),
            ),
            Icons.medical_services_rounded,
            const Color(0xFF10B981),
          ),
          (
            'Admins',
            n((u) => u['role'] == 'admin' || u['role'] == 'superadmin'),
            Icons.shield_rounded,
            const Color(0xFFF59E0B),
          ),
          (
            'ID reviews',
            n((u) => u['role'] == 'student' && u['idVerificationStatus'] == 'pending'),
            Icons.hourglass_top_rounded,
            const Color(0xFFE11D48),
          ),
        ];
        return ResponsiveWrapGrid(
          minTileWidth: 170,
          maxColumns: 4,
          children: [
            for (final t in tiles)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: t.$4.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.$3, color: t.$4, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snap.hasData ? '${t.$2}' : '–',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              t.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _actionCard(_ConsoleAction a) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: a.onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(a.icon, color: a.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(a.subtitle, style: const TextStyle(fontSize: 12, color: BaustColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _ConsoleAction {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ConsoleAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
