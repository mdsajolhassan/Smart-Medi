import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medi/features/admin_portal/presentation/screens/id_verification_review_screen.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/auth_rbac/presentation/screens/student_id_verification_screen.dart';
import 'package:smart_medi/features/medical_onboarding_ai/data/services/gemini_ai_service.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _MockAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

// 1x1 transparent PNG
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

UserProfile _student({String? idStatus, String onboarding = 'DOCS_PENDING', String? note}) => UserProfile(
      uid: 's1',
      email: 'sajol@baust.edu.bd',
      displayName: 'MD. Sajol Hassan',
      role: 'student',
      studentRoll: '0802420205101137',
      profileCompleted: true,
      onboardingStatus: onboarding,
      idVerificationStatus: idStatus,
      idReviewNote: note,
    );

Future<void> _pump(WidgetTester tester, Widget child, UserProfile user) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _MockAuthNotifier(AuthState(status: AuthStatus.authenticated, userProfile: user)),
      ),
    ],
    child: MaterialApp(home: child),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('needsIdVerification gate', () {
    test('new students are gated until verified', () {
      expect(_student(idStatus: 'not_submitted').needsIdVerification, isTrue);
      expect(_student(idStatus: 'pending').needsIdVerification, isTrue);
      expect(_student(idStatus: 'rejected').needsIdVerification, isTrue);
      expect(_student(idStatus: 'verified').needsIdVerification, isFalse);
    });

    test('legacy students who finished onboarding stay active', () {
      expect(_student(onboarding: 'COMPLETED').needsIdVerification, isFalse);
      expect(_student(onboarding: 'DOCS_PENDING').needsIdVerification, isTrue);
    });

    test('non-students are never gated', () {
      const doc = UserProfile(uid: 'd', email: 'd@baust.edu.bd', displayName: 'Dr', role: 'doctor');
      expect(doc.needsIdVerification, isFalse);
    });
  });

  group('AI ID card comparison', () {
    test('matches name and ID ignoring prefixes and formatting', () {
      final r = GeminiAiService.compareIdCardWithProfile(
        {
          'is_student_id_card': true,
          'is_baust': true,
          'student_name': 'Sajol Hassan',
          'student_id': '0802-4202-0510-1137',
        },
        profileName: 'MD. Sajol Hassan',
        profileStudentId: '0802420205101137',
      );
      expect(r['nameMatch'], isTrue);
      expect(r['idMatch'], isTrue);
      expect(r['looksValid'], isTrue);
    });

    test('flags a different student', () {
      final r = GeminiAiService.compareIdCardWithProfile(
        {'is_student_id_card': true, 'is_baust': true, 'student_name': 'Rahim Uddin', 'student_id': '0802420205109999'},
        profileName: 'MD. Sajol Hassan',
        profileStudentId: '0802420205101137',
      );
      expect(r['nameMatch'], isFalse);
      expect(r['idMatch'], isFalse);
      expect(r['looksValid'], isFalse);
    });
  });

  testWidgets('student uploads ID card, sees AI pre-check and submits', (tester) async {
    PickedIdPhoto? submitted;
    Map<String, dynamic>? submittedCheck;
    await _pump(
      tester,
      StudentIdVerificationScreen(
        watchReview: false,
        onPickOverride: (_) async => PickedIdPhoto(Uint8List.fromList(_png), 'card.png'),
        onAnalyzeOverride: (_) async => {
          'is_student_id_card': true,
          'is_baust': true,
          'student_name': 'MD. Sajol Hassan',
          'student_id': '0802420205101137',
        },
        onSubmitOverride: (p, c) async {
          submitted = p;
          submittedCheck = c;
        },
      ),
      _student(idStatus: 'not_submitted'),
    );

    expect(find.text('Upload your BAUST student ID card'), findsOneWidget);
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();

    expect(find.text('Looks good'), findsOneWidget);
    expect(find.textContaining('Name matches profile', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Submit for Verification'));
    await tester.pumpAndSettle();
    expect(submitted?.mimeType, 'image/png');
    expect(submittedCheck?['looksValid'], isTrue);
  });

  testWidgets('pending student sees review status', (tester) async {
    await _pump(tester, const StudentIdVerificationScreen(watchReview: false), _student(idStatus: 'pending'));
    expect(find.text('ID card under review'), findsOneWidget);
    expect(find.text('Upload your BAUST student ID card'), findsNothing);
  });

  testWidgets('rejected student sees the reason and can re-upload', (tester) async {
    await _pump(
      tester,
      const StudentIdVerificationScreen(watchReview: false),
      _student(idStatus: 'rejected', note: 'Photo is blurry or unreadable'),
    );
    expect(find.text('Reason: Photo is blurry or unreadable'), findsOneWidget);
    expect(find.text('Upload your BAUST student ID card'), findsOneWidget);
  });

  testWidgets('admin approves a pending ID card', (tester) async {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    addTearDown(controller.close);
    final reviews = <String>[];
    const admin = UserProfile(uid: 'a', email: 'admin@baust.edu.bd', displayName: 'Admin', role: 'admin');

    await _pump(
      tester,
      IdVerificationReviewScreen(
        streamOverride: (status) => Stream.value(status == 'pending'
            ? [
                {
                  'uid': 's1',
                  'displayName': 'MD. Sajol Hassan',
                  'studentRoll': '0802420205101137',
                  'department': 'CSE',
                  'email': 'sajol@baust.edu.bd',
                  'imageBase64': base64Encode(_png),
                  'aiCheck': {'isIdCard': true, 'isBaust': true, 'nameMatch': true, 'idMatch': true, 'looksValid': true},
                },
              ]
            : <Map<String, dynamic>>[]),
        onReviewOverride: (uid, approve, note) async => reviews.add('$uid:$approve'),
      ),
      admin,
    );

    expect(find.text('MD. Sajol Hassan'), findsOneWidget);
    expect(find.text('Looks good'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(reviews, ['s1:true']);
  });
}
