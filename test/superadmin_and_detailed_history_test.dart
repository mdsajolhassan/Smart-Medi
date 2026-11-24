import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_medi/core/config/auth_config.dart';
import 'package:smart_medi/features/admin_portal/presentation/screens/superadmin_dashboard.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/dashboard/presentation/screens/detailed_medical_history_screen.dart';
import 'package:smart_medi/features/dashboard/presentation/screens/medical_history_tab_screen.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  AuthState build() => _initialState;
}

void main() {
  group('1. Fixed Super Admin Account & Role Mapping Tests', () {
    test('AuthConfig permanently configures serviceprovidergalib@gmail.com as absolute Super Admin', () {
      expect(AuthConfig.superAdminEmail, equals('serviceprovidergalib@gmail.com'));
      expect(AuthConfig.isSuperAdminEmail('serviceprovidergalib@gmail.com'), isTrue);
      expect(AuthConfig.isSuperAdminEmail('SERVICEPROVIDERGALIB@GMAIL.COM'), isTrue);

      // Verify email type & verification status
      expect(AuthConfig.computeEmailType('serviceprovidergalib@gmail.com'), equals('superadmin'));
      expect(AuthConfig.computeVerificationStatus('serviceprovidergalib@gmail.com'), equals('verified'));
      expect(AuthConfig.isEmailAllowed('serviceprovidergalib@gmail.com'), isTrue);

      // Verify personal email without superadmin privileges
      expect(AuthConfig.isSuperAdminEmail('random.student@gmail.com'), isFalse);
      expect(AuthConfig.computeEmailType('random.student@gmail.com'), equals('personal'));
      expect(AuthConfig.computeVerificationStatus('random.student@gmail.com'), equals('pending'));
    });

    test('UserProfile evaluates isSuperAdmin strictly for serviceprovidergalib@gmail.com and NOT student Sajol', () {
      // Super Admin profile
      final superAdminProfile = UserProfile(
        uid: 'superadmin-001',
        email: 'serviceprovidergalib@gmail.com',
        displayName: 'MD. Sajol Hasan',
        role: 'superadmin',
        accessLevel: 'SuperAdmin',
      );
      expect(superAdminProfile.isSuperAdmin, isTrue);

      // Student institutional account for Sajol Hassan
      final studentSajolProfile = UserProfile(
        uid: 'student-sajol-001',
        email: '0802420205101137@baust.edu.bd',
        displayName: 'MD. Sajol Hassan',
        studentRoll: '0802420205101137',
        role: 'student',
        emailType: 'university',
        verificationStatus: 'verified',
        residentialHall: 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
        roomNumber: '402-B',
      );
      expect(studentSajolProfile.isSuperAdmin, isFalse);
      expect(studentSajolProfile.role, equals('student'));
      expect(studentSajolProfile.studentRoll, equals('0802420205101137'));
    });

    test('Super Admin profile initialization and Firestore payload conforms to superadmin specifications', () {
      final superAdminDocData = {
        'uid': 'superadmin-uid-123',
        'email': 'serviceprovidergalib@gmail.com',
        'displayName': 'MD. Sajol Hasan',
        'role': 'superadmin',
        'emailType': 'superadmin',
        'isSuperAdmin': true,
        'accessLevel': 'SuperAdmin',
        'designation': 'Super Administrator',
        'verificationStatus': 'verified',
        'approved': true,
        'profileCompleted': true,
        'onboardingStatus': 'COMPLETED',
      };

      final profile = UserProfile.fromFirestore('superadmin-uid-123', superAdminDocData);
      expect(profile.isSuperAdmin, isTrue);
      expect(profile.role, equals('superadmin'));
      expect(profile.emailType, equals('superadmin'));
      expect(profile.verificationStatus, equals('verified'));
      expect(profile.profileCompleted, isTrue);
      expect(profile.onboardingStatus, equals('COMPLETED'));
      expect(profile.designation, equals('Super Administrator'));
      expect(profile.accessLevel, equals('SuperAdmin'));

      // If document previously lacked role='superadmin', verify copyWith override logic
      final legacyDoc = UserProfile.fromFirestore('superadmin-uid-123', {
        'email': 'serviceprovidergalib@gmail.com',
        'role': 'student',
      });
      final upgraded = legacyDoc.copyWith(
        role: 'superadmin',
        accessLevel: 'SuperAdmin',
        designation: 'Super Administrator',
        verificationStatus: 'verified',
        emailType: 'superadmin',
        profileCompleted: true,
        onboardingStatus: 'COMPLETED',
      );
      expect(upgraded.role, equals('superadmin'));
      expect(upgraded.isSuperAdmin, isTrue);
      expect(upgraded.emailType, equals('superadmin'));
      expect(upgraded.onboardingStatus, equals('COMPLETED'));
    });

    test('Super Admin bypasses registration domain restrictions and is allowed regardless of policy', () {
      expect(AuthConfig.allowPersonalEmails, isFalse);
      expect(AuthConfig.isEmailAllowed(AuthConfig.superAdminEmail), isTrue);
      expect(AuthConfig.isEmailAllowed('SERVICEPROVIDERGALIB@GMAIL.COM'), isTrue);
      expect(AuthConfig.isEmailAllowed('unauthorized.student@gmail.com'), isFalse);
    });
  });

  group('2. Detailed Medical History & Chronological Clinical Timeline View Tests', () {
    testWidgets('MedicalHistoryTabScreen displays View Detailed Medical History button and opens dossier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final studentProfile = UserProfile(
        uid: 'student-sajol-001',
        email: '0802420205101137@baust.edu.bd',
        displayName: 'MD. Sajol Hassan',
        studentRoll: '0802420205101137',
        role: 'student',
        bloodGroup: 'B+',
        department: 'Dept of CSE',
        residentialHall: 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
        roomNumber: '402-B',
      );

      final authState = AuthState(status: AuthStatus.authenticated, userProfile: studentProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => _MockAuthNotifier(authState))],
          child: const MaterialApp(home: MedicalHistoryTabScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify prominent "View Detailed Medical History" button is present
      final viewHistoryButton = find.text('View Detailed Medical History');
      expect(viewHistoryButton, findsOneWidget);

      // Tap button to navigate to DetailedMedicalHistoryScreen
      await tester.tap(viewHistoryButton);
      await tester.pumpAndSettle();

      // Verify Detailed Medical History Screen is displayed
      expect(find.text('Detailed Medical History & Dossier'), findsOneWidget);
      expect(find.text('A-TO-Z CHRONOLOGICAL CLINICAL TIMELINE'), findsOneWidget);
      expect(find.text('MD. Sajol Hassan'), findsOneWidget);
      expect(find.textContaining('0802420205101137'), findsWidgets);
    });

    testWidgets(
      'DetailedMedicalHistoryScreen renders surgeries, prescriptions, diagnoses, and filters from real data',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final studentProfile = UserProfile(
          uid: 'student-sajol-001',
          email: '0802420205101137@baust.edu.bd',
          displayName: 'MD. Sajol Hassan',
          studentRoll: '0802420205101137',
          role: 'student',
          bloodGroup: 'B+',
          department: 'Dept of CSE',
          residentialHall: 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
          roomNumber: '402-B',
        );

        final authState = AuthState(status: AuthStatus.authenticated, userProfile: studentProfile);

        final realMedicalHistoryData = {
          'procedures': [
            {
              'name': 'Laparoscopic Appendectomy',
              'date': '14 August 2022',
              'facility': 'Department of General Surgery, CMH / Rangpur',
              'details': 'Surgical clearance granted. Full functional recovery.',
            },
          ],
          'historicalProblems': ['Bronchial Asthma (Moderate Persistent)'],
          'prescriptions': [
            {
              'name': 'Salbutamol Inhaler (100 mcg/dose)',
              'prescribed_date': '15 February 2024',
              'dosage': '2 puffs',
              'frequency': 'PRN every 4-6 hours',
              'instructions': '2 puffs inhaled PRN every 4-6 hours during respiratory distress.',
              'doctor': 'BAUST Medical Officer Prescription #BM-8842',
            },
          ],
          'clinicalSummary': 'Vitals stable. Active respiratory plan documented.',
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authControllerProvider.overrideWith(() => _MockAuthNotifier(authState))],
            child: MaterialApp(home: DetailedMedicalHistoryScreen(initialData: realMedicalHistoryData)),
          ),
        );
        await tester.pumpAndSettle();

        // Verify patient header with real profile data
        expect(find.text('MD. Sajol Hassan'), findsOneWidget);
        expect(find.text('B+'), findsOneWidget);
        expect(find.textContaining('0802420205101137'), findsWidgets);
        expect(find.textContaining('Shaheed Dr. Zikrul Haque Hall (SDZHH), Room: 402-B'), findsOneWidget);

        // Verify chronological timeline milestones parsed from real data
        expect(find.text('Laparoscopic Appendectomy'), findsOneWidget);
        expect(find.text('14 August 2022'), findsOneWidget);
        expect(find.text('Bronchial Asthma (Moderate Persistent)'), findsOneWidget);
        expect(find.text('Salbutamol Inhaler (100 mcg/dose)'), findsOneWidget);
        expect(find.text('15 February 2024'), findsOneWidget);

        // Verify category filter chips
        expect(find.widgetWithText(FilterChip, 'Surgeries'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Prescriptions'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Conditions'), findsOneWidget);

        // Filter by "Surgeries"
        await tester.tap(find.widgetWithText(FilterChip, 'Surgeries'));
        await tester.pumpAndSettle();

        // Surgery remains visible, prescriptions hidden
        expect(find.text('Laparoscopic Appendectomy'), findsOneWidget);
        expect(find.text('Salbutamol Inhaler (100 mcg/dose)'), findsNothing);

        // Reset to "All"
        await tester.tap(find.widgetWithText(FilterChip, 'All'));
        await tester.pumpAndSettle();

        // Verify search input filtering
        await tester.enterText(find.byType(TextField).first, 'Salbutamol');
        await tester.pumpAndSettle();

        expect(find.text('Salbutamol Inhaler (100 mcg/dose)'), findsOneWidget);
        expect(find.text('Laparoscopic Appendectomy'), findsNothing);

        // Clear search
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pumpAndSettle();

        // Open Export Dossier Dialog
        await tester.tap(find.byIcon(Icons.print_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Clinical Dossier Export'), findsOneWidget);
        expect(find.textContaining('Patient: MD. Sajol Hassan'), findsOneWidget);
        expect(find.text('Share Summary'), findsOneWidget);

        await tester.tap(find.text('Share Summary'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('DetailedMedicalHistoryScreen displays "Not found - confirm with patient" when data is missing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Empty profile without blood group, roll, hall, or room
      final emptyProfile = const UserProfile(
        uid: 'user-empty',
        email: 'empty@baust.edu.bd',
        displayName: '',
        role: 'student',
      );

      final authState = AuthState(status: AuthStatus.authenticated, userProfile: emptyProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => _MockAuthNotifier(authState))],
          child: const MaterialApp(home: DetailedMedicalHistoryScreen(initialData: {})),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Not found - confirm with patient" displayed for missing data
      expect(find.text('Not found - confirm with patient'), findsWidgets);
      expect(find.text('0 Records'), findsOneWidget);
    });
  });

  group('3. Super Admin Testing & System Accounts Overview Dashboard Tests', () {
    testWidgets('SuperAdminDashboard displays registered accounts and has no SOS testing monitor', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final superAdminProfile = UserProfile(
        uid: 'superadmin-sajol',
        email: 'serviceprovidergalib@gmail.com',
        displayName: 'MD. Sajol Hasan',
        role: 'superadmin',
        accessLevel: 'SuperAdmin',
      );

      final authState = AuthState(status: AuthStatus.authenticated, userProfile: superAdminProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => _MockAuthNotifier(authState))],
          child: const MaterialApp(home: SuperAdminDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify SuperAdmin Banner & Fixed Email
      expect(find.text('MD. Sajol Hasan'), findsWidgets);
      expect(find.textContaining('serviceprovidergalib@gmail.com'), findsWidgets);
      expect(find.textContaining('Absolute SuperAdmin'), findsOneWidget);

      // 2. No hard-coded people: accounts and SOS alerts come only from Firestore
      for (final name in [
        'MD. Sajol Hassan',
        'Dr. Fowzia Jahan',
        'Md. Mozaffor Hossain',
        'Lamia Aktar Limu',
        'Dr. Md Nakib Hayat Chowdhury',
      ]) {
        expect(find.text(name), findsNothing);
      }
      expect(find.textContaining('0802420205101137'), findsNothing);
      expect(find.textContaining('limuakhtar9@gmail.com'), findsNothing);
      expect(find.textContaining('01769-675576'), findsNothing);

      // 3. The SOS testing monitor and simulate tools are gone
      expect(find.text('LIVE EMERGENCY SOS TESTING MONITOR'), findsNothing);
      expect(find.byTooltip('Simulate Student SOS (Test Tool)'), findsNothing);
      expect(find.text('Simulate SOS (Test Tool)'), findsNothing);
    });
  });
}
