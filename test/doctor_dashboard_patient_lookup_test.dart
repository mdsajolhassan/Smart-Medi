import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/dashboard/presentation/screens/detailed_medical_history_screen.dart';
import 'package:smart_medi/features/medical_operations/presentation/screens/doctor_dashboard_screen.dart';
import 'package:smart_medi/features/medical_operations/presentation/screens/patient_lookup_screen.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  AuthState build() => _initialState;
}

void main() {
  final testDoctorProfile = UserProfile(
    uid: 'doctor-001',
    email: 'doctor@baust.edu.bd',
    displayName: 'Dr. Fowzia Jahan',
    role: 'doctor',
    designation: 'Senior Medical Officer',
    verificationStatus: 'verified',
  );

  final doctorAuthState = AuthState(
    status: AuthStatus.authenticated,
    userProfile: testDoctorProfile,
  );

  group('Doctor Dashboard — Patient Lookup & History Widget Tests', () {
    testWidgets('1. PatientLookupScreen renders found student result card with unverified blood group chip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final studentRecord = {
        'uid': 'student-sajol-001',
        'studentId': '0802420205101137',
        'studentRoll': '0802420205101137',
        'displayName': 'MD. Sajol Hassan',
        'department': 'Computer Science & Engineering (CSE)',
        'level': 'Level 4',
        'term': 'Term 2',
        'residentialHall': 'Zikrula Haque Hall',
        'phone': '01712345678',
        'bloodGroup': 'B+',
        'bloodGroupVerified': false,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(doctorAuthState)),
          ],
          child: MaterialApp(
            home: PatientLookupScreen(
              onSearchOverride: (query) async {
                if (query == '0802420205101137') {
                  return [studentRecord];
                }
                return [];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Initial Idle State
      expect(find.text('Ready for Patient Lookup'), findsOneWidget);
      expect(find.text('Enter a Student ID or Roll number above to look up patient details and medical history.'), findsOneWidget);

      // Enter student ID and search
      await tester.enterText(find.byType(TextField), '0802420205101137');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
      await tester.pumpAndSettle();

      // Verify Found Result Card
      expect(find.text('MD. Sajol Hassan'), findsOneWidget);
      expect(find.text('Student ID: 0802420205101137'), findsOneWidget);
      expect(find.text('Computer Science & Engineering (CSE)'), findsOneWidget);
      expect(find.text('Level 4 / Term 2'), findsOneWidget);
      expect(find.text('Zikrula Haque Hall'), findsOneWidget);
      expect(find.text('01712345678'), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'View Patient Medical History'), findsOneWidget);
    });

    testWidgets('2. PatientLookupScreen renders "No student found with this ID" when student does not exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(doctorAuthState)),
          ],
          child: MaterialApp(
            home: PatientLookupScreen(
              onSearchOverride: (query) async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '99999999');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
      await tester.pumpAndSettle();

      expect(find.text('No student found with this ID'), findsOneWidget);
      expect(find.text('Ensure the student roll number is entered correctly without letters or spaces.'), findsOneWidget);
    });

    testWidgets('3. PatientLookupScreen renders friendly error message when query fails', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(doctorAuthState)),
          ],
          child: MaterialApp(
            home: PatientLookupScreen(
              onSearchOverride: (query) async {
                throw Exception('Permission denied / network error');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0802420205101137');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to load student record. Please verify network connection or permissions.'),
        findsOneWidget,
      );
    });

    testWidgets('4. DetailedMedicalHistoryScreen in doctor mode shows top red allergy banner and unverified labels', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final studentProfile = {
        'displayName': 'MD. Sajol Hassan',
        'studentRoll': '0802420205101137',
        'department': 'Computer Science & Engineering (CSE)',
        'bloodGroup': 'B+',
        'residentialHall': 'Zikrula Haque Hall',
        'roomNumber': '402-B',
        'criticalFlags': ['Penicillin Allergy', 'Dust Allergy'],
      };

      final medicalHistoryData = {
        'knownAllergies': ['Penicillin Allergy', 'Dust Allergy'],
        'procedures': [
          {
            'name': 'Appendectomy',
            'date': '10 Jan 2023',
            'facility': 'BAUST CMH',
          },
        ],
        'prescriptions': [
          {
            'name': 'Salbutamol Inhaler',
            'prescribed_date': '15 Feb 2026',
            'dosage': '100mcg',
            'frequency': 'PRN',
            'doctor': 'Dr. Fowzia Jahan',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(doctorAuthState)),
          ],
          child: MaterialApp(
            home: DetailedMedicalHistoryScreen(
              isDoctorView: true,
              patientProfile: studentProfile,
              initialData: medicalHistoryData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Top Red Known Allergies Banner
      expect(find.text('CRITICAL MEDICAL ALERT — KNOWN ALLERGIES'), findsOneWidget);
      expect(find.text('Known Allergies: Penicillin Allergy, Dust Allergy'), findsOneWidget);

      // 2. Verify Patient Dossier Header with unverified blood group chip
      expect(find.text('MD. Sajol Hassan'), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('AI-extracted, unverified - confirm with patient'), findsWidgets);

      // 3. Verify Doctor Mode restricts Print and SOS buttons
      expect(find.byIcon(Icons.print_outlined), findsNothing);
      expect(find.byIcon(Icons.emergency_outlined), findsNothing);
    });

    testWidgets('5. DetailedMedicalHistoryScreen in doctor mode displays fallback for missing allergies and empty history state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final studentProfileWithoutHistory = {
        'displayName': 'Tanvir Rahman',
        'studentRoll': '210401050',
        'department': 'CSE',
        'bloodGroup': 'A+',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(doctorAuthState)),
          ],
          child: MaterialApp(
            home: DetailedMedicalHistoryScreen(
              isDoctorView: true,
              patientProfile: studentProfileWithoutHistory,
              initialData: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify fallback allergy banner
      expect(find.text('CRITICAL MEDICAL ALERT — KNOWN ALLERGIES'), findsOneWidget);
      expect(find.text('Known allergies: Not found - confirm with patient'), findsOneWidget);

      // Verify exact empty history state text
      expect(find.text('This student has not uploaded a medical history yet.'), findsOneWidget);
      expect(find.text('No medical documents or prescriptions have been submitted by this student.'), findsOneWidget);
    });

    testWidgets('6. DoctorDashboardScreen displays Patient Lookup action button and opens lookup screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(doctorAuthState)),
          ],
          child: const MaterialApp(
            home: DoctorDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Patient Lookup quick action button exists on dashboard
      final lookupButton = find.widgetWithText(ElevatedButton, 'Patient Lookup (Student ID & Medical History)');
      expect(lookupButton, findsOneWidget);

      // Tap button and verify navigation to PatientLookupScreen
      await tester.tap(lookupButton);
      await tester.pumpAndSettle();

      expect(find.byType(PatientLookupScreen), findsOneWidget);
      expect(find.text('Patient Lookup — BAUST Medical Center'), findsOneWidget);
    });
  });
}
