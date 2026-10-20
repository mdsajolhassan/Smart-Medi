import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_medi/core/constants/baust_constants.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/emergency_sos/presentation/controllers/sos_controller.dart';
import 'package:smart_medi/features/emergency_sos/presentation/screens/sos_screen.dart';
import 'package:smart_medi/features/dashboard/presentation/screens/profile_tab_screen.dart';
import 'package:smart_medi/features/medical_onboarding_ai/presentation/screens/profile_setup_screen.dart';
import 'package:smart_medi/features/medical_onboarding_ai/data/services/gemini_ai_service.dart';

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

void main() {
  group('Residency Status and Address Unit Tests', () {
    test('1. UserProfile defaults to residential and handles non-residential getters', () {
      final defaultProfile = UserProfile(
        uid: 'user-res-1',
        email: 'res@baust.edu.bd',
        displayName: 'Residential Student',
        role: 'student',
      );

      // Default residency checks
      expect(defaultProfile.residencyStatus, equals('residential'));
      expect(defaultProfile.isResidential, isTrue);
      expect(defaultProfile.effectiveResidentialHall, equals('Shaheed Dr. Zikrul Haque Hall (SDZHH)'));
      expect(defaultProfile.effectiveRoomNumber, equals('402-B'));
      expect(defaultProfile.effectiveLocationSummary, contains('Shaheed Dr. Zikrul Haque Hall (SDZHH)'));
      expect(defaultProfile.effectiveLocationSummary, contains('402-B'));

      // Non-residential profile checks
      final nonResProfile = defaultProfile.copyWith(
        residencyStatus: 'non_residential',
        district: 'Nilphamari',
        upazila: 'Saidpur',
        detailedAddress: 'Railgate, Road 4, House 12',
      );

      expect(nonResProfile.isResidential, isFalse);
      expect(nonResProfile.effectiveResidentialHall, equals('Non-Residential (Day Scholar)'));
      expect(nonResProfile.effectiveRoomNumber, equals('N/A'));
      expect(nonResProfile.effectiveLocationSummary, contains('Nilphamari'));
      expect(nonResProfile.effectiveLocationSummary, contains('Saidpur'));
      expect(nonResProfile.effectiveLocationSummary, contains('Railgate, Road 4, House 12'));
    });

    test('2. UserProfile fromFirestore parses residencyStatus, district, upazila, detailedAddress', () {
      final json = {
        'uid': 'user-nonres-101',
        'email': 'nonres@baust.edu.bd',
        'displayName': 'Day Scholar User',
        'role': 'student',
        'residencyStatus': 'non_residential',
        'district': 'Rangpur',
        'upazila': 'Kotwali',
        'detailedAddress': 'Modern Mor, Green View Mess, Flat 3B',
        'bloodGroup': 'O+',
        'profileCompleted': true,
      };

      final profile = UserProfile.fromFirestore('user-nonres-101', json);
      expect(profile.residencyStatus, equals('non_residential'));
      expect(profile.isResidential, isFalse);
      expect(profile.district, equals('Rangpur'));
      expect(profile.upazila, equals('Kotwali'));
      expect(profile.detailedAddress, equals('Modern Mor, Green View Mess, Flat 3B'));
      expect(profile.effectiveLocationSummary, equals('Modern Mor, Green View Mess, Flat 3B, Kotwali, Rangpur'));
    });

    test('3. BangladeshDistricts constant contains required northern districts', () {
      expect(BangladeshDistricts.districts, contains('Nilphamari'));
      expect(BangladeshDistricts.districts, contains('Rangpur'));
      expect(BangladeshDistricts.districts, contains('Dinajpur'));
      expect(BangladeshDistricts.districts, contains('Dhaka'));
      expect(BangladeshDistricts.districts.length, greaterThanOrEqualTo(64));
    });
  });

  group('Gemini AI Extraction Prompt Clinical Rules Tests', () {
    test('4. System prompt contains Multi-Document Timeline and Latest Data Priority rule', () {
      final prompt = GeminiAiService.systemPrompt;
      expect(prompt, contains('MULTI-DOCUMENT TIMELINE & LATEST DATA PRIORITY'));
      expect(prompt, contains('The most recent prescription or visit takes precedence and defines current status'));
      expect(prompt, contains('HISTORICAL RETENTION (SURGERIES & ADMISSIONS)'));
      expect(prompt, contains('ASD Closure'));
      expect(prompt, contains('Laparoscopic Hernia Repair'));
      expect(prompt, contains('HANDWRITING & UNCLEAR TEXT INTELLIGENCE'));
      expect(prompt, contains('Unverified - confirm with doctor'));
    });
  });

  group('Conditional Onboarding Profile Setup UI Tests', () {
    testWidgets('5. ProfileSetupScreen toggles dynamically between Residential and Non-Residential fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialProfile = UserProfile(
        uid: 'new-student-01',
        email: 'student@baust.edu.bd',
        displayName: 'New Student',
        role: 'student',
        profileCompleted: false,
      );

      final mockAuthState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: initialProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(mockAuthState)),
          ],
          child: const MaterialApp(
            home: ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 1. In default Residential mode:
      // Residential Hall dropdown and Hall Room Number input are visible
      expect(find.text('Residential Hall *'), findsOneWidget);
      expect(find.text('Hall Room Number * (e.g. 402-B)'), findsOneWidget);

      // Non-Residential fields must NOT be visible yet
      expect(find.text('District (জেলা) *'), findsNothing);
      expect(find.text('Upazila / Thana (উপজেলা / থানা) *'), findsNothing);
      expect(find.text('Detailed Address (বিস্তারিত ঠিকানা) *'), findsNothing);

      // 2. Tap on "Non-Residential (অনাবাসিক)" radio/card
      final nonResidentialButton = find.textContaining('Non-Residential').first;
      await tester.tap(nonResidentialButton);
      await tester.pump(const Duration(milliseconds: 200));

      // Residential fields should now be hidden
      expect(find.text('Residential Hall *'), findsNothing);
      expect(find.text('Hall Room Number * (e.g. 402-B)'), findsNothing);

      // Non-Residential fields should now be visible
      expect(find.text('District (জেলা) *'), findsOneWidget);
      expect(find.text('Upazila / Thana (উপজেলা / থানা) *'), findsOneWidget);
      expect(find.text('Detailed Address (বিস্তারিত ঠিকানা) *'), findsOneWidget);

      // 3. Tap back to "Residential (আবাসিক)"
      final residentialButton = find.textContaining('Residential').first;
      await tester.tap(residentialButton);
      await tester.pump(const Duration(milliseconds: 200));

      // Residential fields restored
      expect(find.text('Residential Hall *'), findsOneWidget);
      expect(find.text('Hall Room Number * (e.g. 402-B)'), findsOneWidget);
      expect(find.text('District (জেলা) *'), findsNothing);
    });

    testWidgets('6. SosScreen and ProfileTabScreen display non-residential address accurately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final nonResProfile = UserProfile(
        uid: 'day-scholar-007',
        email: 'scholar@baust.edu.bd',
        displayName: 'Tanim Ahmed',
        role: 'student',
        residencyStatus: 'non_residential',
        district: 'Nilphamari',
        upazila: 'Saidpur',
        detailedAddress: 'Shaheed Smrity Road, Mess 12',
        profileCompleted: true,
      );

      final mockAuthState = AuthState(
        status: AuthStatus.authenticated,
        userProfile: nonResProfile,
      );

      // Test SosScreen shows non-residential address
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(mockAuthState)),
            sosControllerProvider.overrideWith(() => _MockSosNotifier()),
          ],
          child: MaterialApp(
            home: SosScreen(onNavigateToProfile: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('DISPATCH LOCATION (PROFILE RECORD)'), findsOneWidget);
      expect(find.text('District & Upazila'), findsOneWidget);
      expect(find.text('Home Address'), findsOneWidget);
      expect(find.text('Shaheed Smrity Road, Mess 12'), findsOneWidget);
      expect(find.text('Saidpur, Nilphamari'), findsOneWidget);

      // Test ProfileTabScreen shows non-residential address
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier(mockAuthState)),
            sosControllerProvider.overrideWith(() => _MockSosNotifier()),
          ],
          child: const MaterialApp(
            home: ProfileTabScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('NON-RESIDENTIAL EMERGENCY ADDRESS'), findsOneWidget);
      expect(find.textContaining('Shaheed Smrity Road, Mess 12'), findsWidgets);
      expect(find.textContaining('Saidpur, Nilphamari'), findsWidgets);
    });
  });
}
