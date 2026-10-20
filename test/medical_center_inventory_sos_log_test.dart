import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/medical_operations/presentation/controllers/patient_checkin_controller.dart';
import 'package:smart_medi/features/medical_operations/presentation/screens/doctor_dashboard_screen.dart';
import 'package:smart_medi/features/medical_operations/presentation/screens/pharmacist_inventory_screen.dart';
import 'package:smart_medi/features/medical_operations/presentation/screens/patient_checkin_log_screen.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  AuthState build() => _initialState;
}

void main() {
  group('1. Pharmacy Inventory & Multiplier Controls Tests', () {
    testWidgets('Top 5 core medicines strictly initialized to 20 units and multiplier updates stock by ±factor', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PharmacistInventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Top 5 Essential Medicines are displayed
      expect(find.text('Napa 500mg'), findsOneWidget);
      expect(find.text('Seclo 20mg'), findsOneWidget);
      expect(find.text('Metronidazole 400mg'), findsOneWidget);
      expect(find.text('Orsaline-N / SMC ORS'), findsOneWidget);
      expect(find.text('Povidone Iodine 10%'), findsOneWidget);

      // Verify all 5 items start with 20 Units
      expect(find.text('20 Units'), findsNWidgets(5));

      // Verify multiplier selector buttons are rendered (1x, 2x, 5x, 10x, 20x)
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('5x'), findsOneWidget);
      expect(find.text('10x'), findsOneWidget);
      expect(find.text('20x'), findsOneWidget);

      // Default multiplier is 1x -> buttons show -1 and +1
      expect(find.text('-1'), findsNWidgets(5));
      expect(find.text('+1'), findsNWidgets(5));

      // Tap on 5x multiplier selector
      await tester.tap(find.text('5x'));
      await tester.pumpAndSettle();

      // Buttons now reflect -5 and +5
      expect(find.text('-5'), findsNWidgets(5));
      expect(find.text('+5'), findsNWidgets(5));
      expect(find.text('Step: ±5 units'), findsOneWidget);

      // Tap '+5' for the first item (Napa 500mg) -> stock increases from 20 to 25
      await tester.tap(find.text('+5').first);
      await tester.pumpAndSettle();
      expect(find.text('25 Units'), findsOneWidget);

      // Tap '-5' for Napa 500mg -> stock decreases back from 25 to 20
      await tester.tap(find.text('-5').first);
      await tester.pumpAndSettle();
      expect(find.text('20 Units'), findsNWidgets(5));

      // Select 20x multiplier and test full dispense down to 0
      await tester.tap(find.text('20x'));
      await tester.pumpAndSettle();
      expect(find.text('-20'), findsNWidgets(5));
      expect(find.text('+20'), findsNWidgets(5));

      // Dispense 20 units of Napa 500mg
      await tester.tap(find.text('-20').first);
      await tester.pumpAndSettle();
      expect(find.text('0 Units'), findsOneWidget);
    });
  });

  group('2. Patient Check-In & Visit Tracking Log Tests', () {
    test('PatientCheckInNotifier creates and manages check-in records', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(patientCheckInProvider.notifier);
      final initialList = container.read(patientCheckInProvider);

      expect(initialList, isEmpty);

      // Record a new visit entry
      await notifier.addCheckIn(
        studentId: '0802420205101138',
        studentName: 'Ahsan Habib',
        purpose: 'Fever & Flu Examination',
        recordedBy: 'Dr. Fowzia Jahan (Medical Officer)',
        notes: 'Temperature 102F. Given Napa & rest advised.',
      );

      final updatedList = container.read(patientCheckInProvider);
      expect(updatedList.first.studentId, equals('0802420205101138'));
      expect(updatedList.first.studentName, equals('Ahsan Habib'));
      expect(updatedList.first.purpose, equals('Fever & Flu Examination'));
    });

    testWidgets('PatientCheckInLogScreen displays search, timeline, and records new patient entry', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final staffProfile = UserProfile(
        uid: 'staff-001',
        email: '',
        phone: '01712-645975',
        displayName: 'Md. Mozaffor Hossain',
        role: 'pharmacist',
        designation: 'Medical Assistant / Pharmacist',
      );

      final mockAuthState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: staffProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(mockAuthState)),
          ],
          child: const MaterialApp(
            home: PatientCheckInLogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and empty state
      expect(find.text('Medical Center Patient Check-in Log'), findsOneWidget);
      expect(find.text('No check-ins yet.'), findsOneWidget);

      // Open "+ New Check-In" modal
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Record Patient Check-In'), findsOneWidget);
      expect(find.text('Student ID / Roll *'), findsOneWidget);
      expect(find.text('Student Name *'), findsOneWidget);

      // Add a test check-in entry
      await tester.enterText(find.widgetWithText(TextFormField, 'Student ID / Roll *'), '0802420205101137');
      await tester.enterText(find.widgetWithText(TextFormField, 'Student Name *'), 'MD. Sajol Hassan');
      await tester.tap(find.text('Save to Medical Center Staff Log'));
      await tester.pumpAndSettle();

      expect(find.text('MD. Sajol Hassan'), findsOneWidget);
      expect(find.text('ID: 0802420205101137'), findsOneWidget);
    });
  });

  group('3. Doctor Portal Live SOS & Check-In Integration Tests', () {
    testWidgets('DoctorDashboardScreen displays check-in log section and simulates real student SOS', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final docProfile = UserProfile(
        uid: 'doc-fowzia',
        email: 'medicalcenter@baust.edu.bd',
        phone: '01769-675576',
        displayName: 'Dr. Fowzia Jahan',
        role: 'doctor',
        designation: 'Senior Medical Officer',
      );

      final mockAuthState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: docProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(mockAuthState)),
          ],
          child: const MaterialApp(
            home: DoctorDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Doctor Portal rendered with Check-in Section
      expect(find.text('Doctor Portal — BAUST Medical Center'), findsOneWidget);
      expect(find.text('PATIENT CHECK-IN & VISIT TRACKER'), findsOneWidget);
      expect(find.text('Patient Check-In Log'), findsOneWidget);
      expect(find.text('Pharmacy Inventory'), findsOneWidget);

      // Verify no hardcoded dummy student "Tanvir Rahman"
      expect(find.text('Tanvir Rahman'), findsNothing);

      // Trigger incoming SOS simulation
      final simulateButton = find.byTooltip('Simulate Incoming SOS Alert');
      expect(simulateButton, findsOneWidget);
      await tester.tap(simulateButton);
      await tester.pumpAndSettle();

      // Verify dynamic student alert for MD. Sajol Hassan is displayed in queue
      expect(find.text('MD. Sajol Hassan'), findsWidgets);
      expect(find.textContaining('0802420205101137'), findsWidgets);
      expect(find.textContaining('Shaheed Dr. Zikrul Haque Hall (SDZHH)'), findsWidgets);
      expect(find.text('DISPATCH AMBULANCE'), findsOneWidget);
      expect(find.text('Document Check-In'), findsOneWidget);

      // Dispatch Ambulance
      await tester.tap(find.text('DISPATCH AMBULANCE'));
      await tester.pumpAndSettle();
      expect(find.text('AMBULANCE ON ROUTE'), findsOneWidget);

      // 1-Tap Document in Medical Center Staff Log
      await tester.tap(find.text('Document Check-In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify snackbar confirmation
      expect(find.textContaining('Documented in Medical Center Staff Log for MD. Sajol Hassan'), findsOneWidget);
    });
  });
}
