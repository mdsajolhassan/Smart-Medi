import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/smart_medi_drawer.dart';
import '../../../admin_portal/presentation/screens/superadmin_dashboard.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../blood_bank/presentation/screens/blood_donor_directory.dart';
import '../../../emergency_sos/presentation/screens/sos_screen.dart';
import 'profile_tab_screen.dart';
import 'medical_history_tab_screen.dart';

class MainDashboardScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MainDashboardScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends ConsumerState<MainDashboardScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Emergency Medical SOS';
      case 1:
        return 'Student Profile & Location';
      case 2:
        return 'Campus Blood Bank';
      case 3:
        return 'AI Medical Summary';
      default:
        return 'Smart Medi — BAUST';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

    final tabs = [
      SosScreen(
        showAppBar: false,
        onNavigateToProfile: () => setState(() => _currentIndex = 1),
      ),
      const ProfileTabScreen(),
      const BloodDonorDirectoryScreen(showAppBar: false),
      const MedicalHistoryTabScreen(),
    ];

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      drawer: const SmartMediDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
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
            Flexible(
              child: Text(
                _getTabTitle(_currentIndex),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (isSuperAdmin)
            IconButton(
              tooltip: 'Super Admin Portal',
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: Colors.black, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SuperAdminDashboard()),
                );
              },
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: _currentIndex == 0 || _currentIndex == 2
            ? Colors.red.shade100
            : BaustColors.primaryArmyGreen.withValues(alpha: 0.15),
        backgroundColor: Colors.white,
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.touch_app_outlined),
            selectedIcon: Icon(Icons.touch_app, color: BaustColors.emergencyRed),
            label: 'Home / SOS',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: BaustColors.primaryArmyGreen),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism, color: BaustColors.emergencyRed),
            label: 'Blood Bank',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_information_outlined),
            selectedIcon: Icon(Icons.medical_information, color: BaustColors.primaryArmyGreen),
            label: 'Medical History',
          ),
        ],
      ),
    );
  }
}
