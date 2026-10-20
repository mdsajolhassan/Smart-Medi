import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/emergency_sos/presentation/controllers/sos_controller.dart';
import 'package:smart_medi/features/emergency_sos/presentation/screens/sos_screen.dart';
import 'package:smart_medi/features/dashboard/presentation/screens/main_dashboard_screen.dart';

void main() {
  group('Phase 1 Dashboard & SuperAdmin Refactoring Tests', () {
    test('1. UserProfile persistent Hall, Room Number & SuperAdmin properties', () {
      final defaultProfile = UserProfile(
        uid: 'user-001',
        email: 'student@baust.edu.bd',
        displayName: 'Rahim Khan',
        role: 'student',
      );

      // Verify defaults
      expect(defaultProfile.effectiveResidentialHall, equals('Shaheed Dr. Zikrul Haque Hall (SDZHH)'));
      expect(defaultProfile.effectiveRoomNumber, equals('402-B'));
      expect(defaultProfile.isSuperAdmin, isFalse);

      // Verify custom hall and room
      final customProfile = defaultProfile.copyWith(
        residentialHall: 'Abbas Uddin Ahmed Hall (AUAH)',
        roomNumber: '315-A',
      );
      expect(customProfile.effectiveResidentialHall, equals('Abbas Uddin Ahmed Hall (AUAH)'));
      expect(customProfile.effectiveRoomNumber, equals('315-A'));
      expect(customProfile.residentialHall, equals('Abbas Uddin Ahmed Hall (AUAH)'));
      expect(customProfile.roomNumber, equals('315-A'));

      // Verify SuperAdmin recognition
      final adminProfile = defaultProfile.copyWith(
        role: 'superadmin',
        accessLevel: 'SuperAdmin',
      );
      expect(adminProfile.isSuperAdmin, isTrue);

      final sajolProfile = UserProfile(
        uid: 'sajol-001',
        email: 'sajol@baust.edu.bd',
        displayName: 'Sajol Hassan',
        role: 'superadmin',
      );
      expect(sajolProfile.isSuperAdmin, isTrue);
    });

    test('2. UserProfile fromFirestore parses roomNumber', () {
      final docData = {
        'uid': 'student-123',
        'email': 'student@baust.edu.bd',
        'displayName': 'Sajol Hassan',
        'role': 'student',
        'residentialHall': 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
        'roomNumber': '204-C',
        'bloodGroup': 'B+',
        'bloodGroupVerified': false,
        'profileCompleted': true,
      };

      final profile = UserProfile.fromFirestore('student-123', docData);
      expect(profile.roomNumber, equals('204-C'));
      expect(profile.effectiveRoomNumber, equals('204-C'));
      expect(profile.effectiveResidentialHall, equals('Shaheed Dr. Zikrul Haque Hall (SDZHH)'));
    });

    testWidgets('3. SosScreen shows persistent location and dynamic Other Critical Emergency input', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testProfile = UserProfile(
        uid: 'test-sos-user',
        email: 'test@baust.edu.bd',
        displayName: 'Test User',
        role: 'student',
        residentialHall: 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
        roomNumber: '501-A',
        profileCompleted: true,
        onboardingStatus: 'COMPLETED',
      );

      final mockAuthState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: testProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(mockAuthState)),
            sosControllerProvider.overrideWith(() => _MockSosNotifier()),
          ],
          child: MaterialApp(
            home: SosScreen(
              onNavigateToProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify persistent location card displays registered hall and room
      expect(find.textContaining('Shaheed Dr. Zikrul Haque Hall (SDZHH)'), findsOneWidget);
      expect(find.textContaining('501-A'), findsOneWidget);
      expect(find.text('Edit in Profile'), findsOneWidget);

      // Initially, custom description input should NOT be present
      expect(find.text('Specify Critical Emergency Condition *'), findsNothing);

      // Open the Symptom Category dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pump(const Duration(milliseconds: 300));

      // Select "Other Critical Emergency"
      final otherOption = find.text('Other Critical Emergency').last;
      await tester.tap(otherOption);
      await tester.pump(const Duration(milliseconds: 300));

      // Custom emergency text field must now be dynamically revealed
      expect(find.text('Specify Critical Emergency Condition *'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('4. MainDashboardScreen renders 4 navigation bar destinations', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final adminProfile = UserProfile(
        uid: 'sajol-admin',
        email: 'sajol.hassan@baust.edu.bd',
        displayName: 'Sajol Hassan',
        role: 'superadmin',
        residentialHall: 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
        roomNumber: '402-B',
        profileCompleted: true,
        onboardingStatus: 'COMPLETED',
      );

      final mockAuthState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: adminProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(mockAuthState)),
            sosControllerProvider.overrideWith(() => _MockSosNotifier()),
          ],
          child: const MaterialApp(
            home: MainDashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the 4 destinations exist
      expect(find.text('Home / SOS'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Blood Bank'), findsOneWidget);
      expect(find.text('Medical History'), findsOneWidget);

      // Verify SuperAdmin badge/button is present for Sajol Hassan
      expect(find.text('ADMIN'), findsOneWidget);
    });
  });
}

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  AuthState build() => _initialState;
}

class _MockSosNotifier extends SosNotifier {
  @override
  SosState build() => SosState.initial();
}
