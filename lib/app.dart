import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/auth_config.dart';
import 'core/theme/app_theme.dart';
import 'features/advisor_portal/presentation/screens/staff_dashboard_screen.dart';
import 'features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'features/auth_rbac/presentation/screens/login_screen.dart';
import 'features/auth_rbac/presentation/screens/email_verification_screen.dart';
import 'features/auth_rbac/presentation/screens/waiting_for_approval_screen.dart';
import 'features/auth_rbac/presentation/screens/role_placeholder_screen.dart';
import 'features/auth_rbac/presentation/screens/student_id_verification_screen.dart';
import 'features/dashboard/presentation/screens/main_dashboard_screen.dart';
import 'features/medical_onboarding_ai/presentation/screens/profile_setup_screen.dart';
import 'features/medical_onboarding_ai/presentation/screens/medical_onboarding_screen.dart';
import 'features/medical_operations/presentation/screens/doctor_dashboard_screen.dart';
import 'features/admin_portal/presentation/screens/admin_console_screen.dart';
import 'features/auth_rbac/presentation/screens/account_removed_screen.dart';

class SmartMediApp extends ConsumerWidget {
  const SmartMediApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Smart Medi — BAUST',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Keep layouts intact on small phones with very large system fonts.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3)),
          child: child!,
        );
      },
      home: _resolveHomeRoute(authState),
    );
  }

  Widget _resolveHomeRoute(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.initial:
        return const BrandedLoader();

      case AuthStatus.loading:
        // If an authenticated user is actively reloading their state, display loading splash
        if (authState.userProfile != null) {
          return const BrandedLoader();
        }
        // If logging in from LoginScreen, preserve LoginScreen so the button-level loading spinner spins cleanly
        return const LoginScreen();

      case AuthStatus.authenticated:
        final user = authState.userProfile;
        final role = user?.role.toLowerCase() ?? 'student';

        // Removed (soft-deleted) accounts are blocked everywhere
        if (user != null && user.isRemoved && !user.isSuperAdmin) {
          return const AccountRemovedScreen();
        }

        // Admin & Super Admin: account management console (no access to other users' dashboards)
        if (user?.isAdmin == true || AuthConfig.isSuperAdminEmail(user?.email ?? '')) {
          return const AdminConsoleScreen();
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
        // Legacy clinical roles all use the doctor dashboard (4-role model)
        if (role == 'pharmacist' || role == 'medical_assistant' || role == 'nurse') {
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

        // 2. New students stay inactive until an admin verifies their student ID card
        if (user.needsIdVerification) {
          return const StudentIdVerificationScreen();
        }

        // 3. If medical onboarding not completed: route to AI Medical History Onboarding
        if (user.onboardingStatus != 'COMPLETED') {
          return const MedicalOnboardingScreen();
        }

        // 4. Completed: Main Emergency SOS & Medical Dashboard (4 Tabs)
        return const MainDashboardScreen();

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}
