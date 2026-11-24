import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/profile/presentation/screens/edit_profile_screen.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _MockAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

Future<void> _pump(WidgetTester tester, UserProfile user, Future<void> Function(Map<String, dynamic>) onSave) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _MockAuthNotifier(AuthState(status: AuthStatus.authenticated, userProfile: user)),
        ),
      ],
      child: MaterialApp(home: EditProfileScreen(onSaveOverride: onSave)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const student = UserProfile(
    uid: 's1',
    email: 'sajol@baust.edu.bd',
    displayName: 'MD. Sajol Hassan',
    role: 'student',
    studentRoll: '0802420205101137',
    department: 'Computer Science & Engineering (CSE)',
    level: 'Level 2',
    term: 'Term 1',
    residentialHall: 'Abbas Uddin Ahmed Hall (AUAH)',
    roomNumber: '210',
    phone: '01712345678',
    bloodGroup: 'B+',
  );

  const doctor = UserProfile(
    uid: 'd1',
    email: 'doctor@baust.edu.bd',
    displayName: 'Dr. Fowzia Jahan',
    role: 'doctor',
    designation: 'Medical Officer',
    bmdcRegistrationNumber: 'A-12345',
  );

  testWidgets('student sees academic, residence and blood sections and can save edits', (tester) async {
    Map<String, dynamic>? saved;
    await _pump(tester, student, (v) async => saved = v);

    expect(find.text('Academic'), findsOneWidget);
    expect(find.text('Residence'), findsOneWidget);
    expect(find.text('Blood donation'), findsOneWidget);
    expect(find.text('Professional'), findsNothing);
    expect(find.text('0802420205101137'), findsOneWidget); // read-only Student ID

    await tester.enterText(find.widgetWithText(TextFormField, 'Room number *'), '305');
    await tester.tap(find.text('List me as a voluntary donor'));
    await tester.pump();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['roomNumber'], '305');
    expect(saved!['isWillingToDonateBlood'], isTrue);
    expect(saved!['residentialHall'], 'Abbas Uddin Ahmed Hall (AUAH)');
    expect(saved!.containsKey('bmdcRegistrationNumber'), isFalse);
  });

  testWidgets('switching a student to day scholar shows home address fields', (tester) async {
    Map<String, dynamic>? saved;
    await _pump(tester, student, (v) async => saved = v);

    await tester.tap(find.text('Day scholar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Room number *'), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Upazila / Thana'), 'Saidpur');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(saved!['residencyStatus'], 'non_residential');
    expect(saved!['upazila'], 'Saidpur');
    expect(saved!['residentialHall'], isNull);
  });

  testWidgets('doctor sees professional section and BMDC is validated', (tester) async {
    Map<String, dynamic>? saved;
    await _pump(tester, doctor, (v) async => saved = v);

    expect(find.text('Professional'), findsOneWidget);
    expect(find.text('Academic'), findsNothing);
    expect(find.text('Residence'), findsNothing);

    final bmdc = find.widgetWithText(TextFormField, 'BMDC registration number');
    await tester.enterText(bmdc, '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Required for doctors'), findsOneWidget);
    expect(saved, isNull);

    await tester.enterText(bmdc, 'A-67890');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '01811223344');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(saved!['bmdcRegistrationNumber'], 'A-67890');
    expect(saved!['designation'], 'Medical Officer');
    expect(saved!['phone'], '01811223344');
    expect(saved!.containsKey('roomNumber'), isFalse);
  });

  testWidgets('invalid phone number is rejected', (tester) async {
    Map<String, dynamic>? saved;
    await _pump(tester, doctor, (v) async => saved = v);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '12345');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid Bangladeshi mobile number'), findsOneWidget);
    expect(saved, isNull);
  });
}
