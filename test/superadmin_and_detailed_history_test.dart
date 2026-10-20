import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_medi/core/config/auth_config.dart';
import 'package:smart_medi/core/constants/baust_constants.dart';
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
    test('AuthConfig permanently configures mdsajolhasan5@gmail.com as absolute Super Admin', () {
      expect(AuthConfig.superAdminEmail, equals('mdsajolhasan5@gmail.com'));
      expect(AuthConfig.isSuperAdminEmail('mdsajolhasan5@gmail.com'), isTrue);
      expect(AuthConfig.isSuperAdminEmail('MDSAJOLHASAN5@GMAIL.COM'), isTrue);

      // Verify email type & verification status
      expect(AuthConfig.computeEmailType('mdsajolhasan5@gmail.com'), equals('superadmin'));
      expect(AuthConfig.computeVerificationStatus('mdsajolhasan5@gmail.com'), equals('verified'));
      expect(AuthConfig.isEmailAllowed('mdsajolhasan5@gmail.com'), isTrue);

      // Verify personal email without superadmin privileges
      expect(AuthConfig.isSuperAdminEmail('random.student@gmail.com'), isFalse);
      expect(AuthConfig.computeEmailType('random.student@gmail.com'), equals('personal'));
      expect(AuthConfig.computeVerificationStatus('random.student@gmail.com'), equals('pending'));
    });

    test('UserProfile evaluates isSuperAdmin strictly for mdsajolhasan5@gmail.com and NOT student Sajol', () {
      // Super Admin profile
      final superAdminProfile = UserProfile(
        uid: 'superadmin-001',
        email: 'mdsajolhasan5@gmail.com',
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
        'email': 'mdsajolhasan5@gmail.com',
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
        'email': 'mdsajolhasan5@gmail.com',
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
      expect(AuthConfig.isEmailAllowed('MDSAJOLHASAN5@GMAIL.COM'), isTrue);
      expect(AuthConfig.isEmailAllowed('unauthorized.student@gmail.com'), isFalse);
    });

    test('BaustSeedData medicalStaff and initialFaculty conform strictly to authentic records with zero mock emails', () {
      // 1. Dr. Fowzia Jahan
      final fowzia = BaustSeedData.medicalStaff.firstWhere((s) => s['name'] == 'Dr. Fowzia Jahan');
      expect(fowzia['email'], equals('medicalcenter@baust.edu.bd'));
      expect(fowzia['phone'], equals('01769-675576'));
      expect(fowzia['designation'], equals('Senior Medical Officer'));
      expect(fowzia['role'], equals('doctor'));

      // 2. Md. Mozaffor Hossain (no email, only phone)
      final mozaffor = BaustSeedData.medicalStaff.firstWhere((s) => s['name'] == 'Md. Mozaffor Hossain');
      expect(mozaffor['email'], isNull);
      expect(mozaffor['phone'], equals('01712-645975'));
      expect(mozaffor['designation'], equals('Medical Assistant'));
      expect(mozaffor['role'], equals('pharmacist'));

      // 3. Lamia Aktar Limu
      final limu = BaustSeedData.medicalStaff.firstWhere((s) => s['name'] == 'Lamia Aktar Limu');
      expect(limu['email'], equals('limuakhtar9@gmail.com'));
      expect(limu['phone'], equals('01749-898473'));
      expect(limu['designation'], equals('Staff Nurse'));

      // 4. Dr. Md Nakib Hayat Chowdhury: Strictly Head of Department (CSE), no advisor roles, no mock email
      final nakib = BaustSeedData.initialFaculty.firstWhere((f) => f['name'] == 'Dr. Md Nakib Hayat Chowdhury');
      expect(nakib['designation'], equals('Head of Department (CSE) / Associate Professor'));
      expect(nakib['accessLevel'], equals('Head of Department (Head)'));
      expect(nakib['email'], isNull);
      expect(nakib['phone'], equals('01769675560'));

      // 5. Zero mock emails policy across initialFaculty
      for (final faculty in BaustSeedData.initialFaculty) {
        final email = faculty['email'];
        if (email != null) {
          expect(email.contains('head.'), isFalse);
          expect(email, isNot(equals('fowzia@baust.edu.bd')));
          expect(email, isNot(equals('mozaffor@baust.edu.bd')));
          expect(email, isNot(equals('limu@baust.edu.bd')));
          expect(email, isNot(equals('nakib@baust.edu.bd')));
        }
      }
    });
  });

  group('2. Detailed Medical History & Chronological Clinical Timeline View Tests', () {
    testWidgets('MedicalHistoryTabScreen displays View Detailed Medical History button and opens dossier', (tester) async {
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

      final authState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: studentProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(authState)),
          ],
          child: const MaterialApp(
            home: MedicalHistoryTabScreen(),
          ),
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

    testWidgets('DetailedMedicalHistoryScreen renders surgeries, prescriptions, diagnoses, and filters from real data', (tester) async {
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

      final authState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: studentProfile,
      );

      final realMedicalHistoryData = {
        'procedures': [
          {
            'name': 'Laparoscopic Appendectomy',
            'date': '14 August 2022',
            'facility': 'Department of General Surgery, CMH / Rangpur',
            'details': 'Surgical clearance granted. Full functional recovery.',
          },
        ],
        'historicalProblems': [
          'Bronchial Asthma (Moderate Persistent)',
        ],
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
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(authState)),
          ],
          child: MaterialApp(
            home: DetailedMedicalHistoryScreen(initialData: realMedicalHistoryData),
          ),
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
    });

    testWidgets('DetailedMedicalHistoryScreen displays "Not found - confirm with patient" when data is missing', (tester) async {
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

      final authState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: emptyProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(authState)),
          ],
          child: const MaterialApp(
            home: DetailedMedicalHistoryScreen(initialData: {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Not found - confirm with patient" displayed for missing data
      expect(find.text('Not found - confirm with patient'), findsWidgets);
      expect(find.text('0 Records'), findsOneWidget);
    });
  });

  group('3. Super Admin Testing & System Accounts Overview Dashboard Tests', () {
    testWidgets('SuperAdminDashboard displays registered accounts, live SOS monitor, and test actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final superAdminProfile = UserProfile(
        uid: 'superadmin-sajol',
        email: 'mdsajolhasan5@gmail.com',
        displayName: 'MD. Sajol Hasan',
        role: 'superadmin',
        accessLevel: 'SuperAdmin',
      );

      final authState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: superAdminProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(authState)),
          ],
          child: const MaterialApp(
            home: SuperAdminDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify SuperAdmin Banner & Fixed Email
      expect(find.text('MD. Sajol Hasan'), findsWidgets);
      expect(find.textContaining('mdsajolhasan5@gmail.com'), findsWidgets);
      expect(find.textContaining('Absolute SuperAdmin'), findsOneWidget);

      // 2. Verify Demo System Accounts Section labeled clearly as [TEST TOOLS]
      expect(find.text('DEMO SYSTEM ACCOUNTS [TEST TOOLS]'), findsOneWidget);

      // Verify registered student account: MD. Sajol Hassan (0802420205101137)
      expect(find.text('MD. Sajol Hassan'), findsWidgets);
      expect(find.text('Student ID: 0802420205101137'), findsOneWidget);
      expect(find.text('0802420205101137@baust.edu.bd'), findsOneWidget);

      // Verify clinical staff accounts: Doctor, Pharmacist, Nurse
      expect(find.text('Dr. Fowzia Jahan'), findsWidgets);
      expect(find.text('medicalcenter@baust.edu.bd'), findsWidgets);
      expect(find.text('01769-675576'), findsWidgets);
      expect(find.text('Md. Mozaffor Hossain'), findsWidgets);
      expect(find.text('01712-645975'), findsWidgets);
      expect(find.text('Lamia Aktar Limu'), findsWidgets);
      expect(find.text('limuakhtar9@gmail.com'), findsWidgets);
      expect(find.text('01749-898473'), findsWidgets);

      // Verify Test Tool badges on demo accounts
      expect(find.text('Test Tool'), findsWidgets);

      // Verify removal of mock/guessed emails
      expect(find.text('fowzia@baust.edu.bd'), findsNothing);
      expect(find.text('mozaffor@baust.edu.bd'), findsNothing);
      expect(find.text('limu@baust.edu.bd'), findsNothing);
      expect(find.text('nakib@baust.edu.bd'), findsNothing);

      // Verify Dr. Md Nakib Hayat Chowdhury is strictly Head of Department, not Hall/Faculty Advisor
      expect(find.text('Dr. Md Nakib Hayat Chowdhury'), findsWidgets);
      expect(find.text('Head of Department (CSE)'), findsWidgets);
      expect(find.textContaining('Hall Advisor'), findsNothing);
      expect(find.textContaining('Approved Faculty Advisor'), findsNothing);

      // 3. Verify Account Filter Chips
      expect(find.widgetWithText(FilterChip, 'All Accounts'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Students'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Doctors'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Pharmacists & Nurses'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'SuperAdmin'), findsOneWidget);

      // Filter by "Students"
      await tester.tap(find.widgetWithText(FilterChip, 'Students'));
      await tester.pumpAndSettle();

      expect(find.text('MD. Sajol Hassan'), findsWidgets);
      expect(find.text('Student ID: 0802420205101137'), findsOneWidget);

      // Filter by "SuperAdmin"
      await tester.tap(find.widgetWithText(FilterChip, 'SuperAdmin'));
      await tester.pumpAndSettle();

      expect(find.textContaining('mdsajolhasan5@gmail.com'), findsWidgets);
      expect(find.text('Student ID: 0802420205101137'), findsNothing);

      // Reset to All Accounts
      await tester.tap(find.widgetWithText(FilterChip, 'All Accounts'));
      await tester.pumpAndSettle();

      // 4. Verify Live Emergency SOS Queue & Testing Monitor
      expect(find.text('LIVE EMERGENCY SOS TESTING MONITOR'), findsOneWidget);
      expect(find.textContaining('Shaheed Dr. Zikrul Haque Hall (SDZHH) • Room 402-B'), findsWidgets);
      expect(find.text('DISPATCH AMBULANCE'), findsOneWidget);

      // Dispatch Ambulance
      await tester.tap(find.text('DISPATCH AMBULANCE'));
      await tester.pumpAndSettle();

      expect(find.text('AMBULANCE ON ROUTE'), findsOneWidget);

      // Trigger Simulated SOS (labeled as Test Tool)
      expect(find.text('Simulate SOS (Test Tool)'), findsOneWidget);
      await tester.tap(find.byTooltip('Simulate Student SOS (Test Tool)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Simulated SOS triggered for Student MD. Sajol Hassan'), findsOneWidget);
    });
  });
}
