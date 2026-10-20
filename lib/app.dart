import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/auth_config.dart';
import 'core/constants/baust_constants.dart';
import 'features/advisor_portal/presentation/screens/staff_dashboard_screen.dart';
import 'features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'features/auth_rbac/presentation/screens/login_screen.dart';
import 'features/auth_rbac/presentation/screens/email_verification_screen.dart';
import 'features/auth_rbac/presentation/screens/waiting_for_approval_screen.dart';
import 'features/auth_rbac/presentation/screens/role_placeholder_screen.dart';
import 'features/dashboard/presentation/screens/main_dashboard_screen.dart';
import 'features/medical_onboarding_ai/presentation/screens/profile_setup_screen.dart';
import 'features/medical_onboarding_ai/presentation/screens/medical_onboarding_screen.dart';
import 'features/medical_operations/presentation/screens/doctor_dashboard_screen.dart';
import 'features/medical_operations/presentation/screens/pharmacist_inventory_screen.dart';

class SmartMediApp extends ConsumerWidget {
  const SmartMediApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Smart Medi — BAUST',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: BaustColors.surfaceBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: BaustColors.primaryArmyGreen,
          primary: BaustColors.primaryArmyGreen,
          secondary: BaustColors.emergencyRed,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: BaustColors.primaryArmyGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: BaustColors.primaryArmyGreen, width: 2),
          ),
        ),
      ),
      home: _resolveHomeRoute(authState),
    );
  }

  Widget _resolveHomeRoute(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.initial:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: BaustColors.primaryArmyGreen),
                SizedBox(height: 16),
                Text(
                  'Authenticating with BAUST Portal...',
                  style: TextStyle(
                    color: BaustColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );

      case AuthStatus.loading:
        // If an authenticated user is actively reloading their state, display loading splash
        if (authState.userProfile != null) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: BaustColors.primaryArmyGreen),
                  SizedBox(height: 16),
                  Text(
                    'Authenticating with BAUST Portal...',
                    style: TextStyle(
                      color: BaustColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // If logging in from LoginScreen, preserve LoginScreen so the button-level loading spinner spins cleanly
        return const LoginScreen();

      case AuthStatus.authenticated:
        final user = authState.userProfile;
        final role = user?.role.toLowerCase() ?? 'student';

        // SuperAdmin / Admin has full multi-tab dashboard access & control center:
        if (user?.isSuperAdmin == true || role == 'superadmin' || role == 'admin' || AuthConfig.isSuperAdminEmail(user?.email ?? '')) {
          return const MainDashboardScreen();
        }

        // Phase 1 Hardening: If account verificationStatus is pending (e.g. personal email) or rejected, route immediately to WaitingForApprovalScreen
        if (user != null && (user.verificationStatus == 'pending' || user.verificationStatus == 'rejected')) {
          return const WaitingForApprovalScreen();
        }

        // Enforce Firebase Email Verification before entering main app (Google accounts are pre-verified)
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && !currentUser.emailVerified) {
          return const EmailVerificationScreen();
        }

        // Dedicated medical operations & staff dashboards:
        if (role == 'doctor' || role == 'medical_officer') {
          return const DoctorDashboardScreen();
        }
        if (role == 'pharmacist') {
          return const PharmacistInventoryScreen();
        }
        if (role == 'medical_assistant' || role == 'nurse') {
          // Medical Assistants & Nurses access Medical Center clinical operations & check-in log
          return const DoctorDashboardScreen();
        }
        if (role == 'staff') {
          return const StaffDashboardScreen();
        }

        // Other non-student roles fallback:
        if (role != 'student') {
          return RolePlaceholderScreen(role: user?.role ?? role);
        }

        // Student multi-stage onboarding workflow:
        // 1. If profile incomplete: route to Student Profile Onboarding Form
        if (user == null ||
            !user.profileCompleted ||
            user.studentRoll == null ||
            user.studentRoll!.isEmpty ||
            user.onboardingStatus == 'PROFILE_PENDING') {
          return const ProfileSetupScreen();
        }

        // 2. If medical onboarding not completed: route to AI Medical History Onboarding
        if (user.onboardingStatus != 'COMPLETED') {
          return const MedicalOnboardingScreen();
        }

        // 3. Completed: Main Emergency SOS & Medical Dashboard (4 Tabs)
        return const MainDashboardScreen();

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}
