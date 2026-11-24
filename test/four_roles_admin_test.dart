import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medi/features/admin_portal/data/user_admin_service.dart';
import 'package:smart_medi/features/admin_portal/presentation/screens/feedback_screens.dart';
import 'package:smart_medi/features/admin_portal/presentation/screens/user_management_screen.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _MockAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

const _admin = UserProfile(uid: 'a1', email: 'admin@baust.edu.bd', displayName: 'Admin One', role: 'admin');
const _super = UserProfile(uid: 'sa', email: 'super@baust.edu.bd', displayName: 'Super Admin', role: 'superadmin');

final _users = <Map<String, dynamic>>[
  {'uid': 'a1', 'displayName': 'Admin One', 'email': 'admin@baust.edu.bd', 'role': 'admin'},
  {'uid': 'a2', 'displayName': 'Admin Two', 'email': 'admin2@baust.edu.bd', 'role': 'admin'},
  {'uid': 'sa', 'displayName': 'Super Admin', 'email': 'super@baust.edu.bd', 'role': 'superadmin'},
  {'uid': 'd1', 'displayName': 'Dr. Fowzia', 'email': 'doc@baust.edu.bd', 'role': 'doctor'},
  {'uid': 'n1', 'displayName': 'Nurse Rina', 'email': 'nurse@baust.edu.bd', 'role': 'nurse'},
  {
    'uid': 's1',
    'displayName': 'Sajol Hassan',
    'email': 'sajol@baust.edu.bd',
    'role': 'student',
    'studentRoll': '0802420205101137',
  },
  {
    'uid': 's2',
    'displayName': 'Removed Student',
    'email': 'gone@baust.edu.bd',
    'role': 'student',
    'accountStatus': 'removed',
  },
];

Future<void> _pump(WidgetTester tester, UserProfile actor, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _MockAuthNotifier(AuthState(status: AuthStatus.authenticated, userProfile: actor)),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Role model', () {
    test('four app roles; legacy clinical roles map to doctor', () {
      expect(UserProfile.appRoles, ['student', 'doctor', 'pharmacist', 'admin', 'superadmin']);
      const nurse = UserProfile(uid: 'n', email: 'n@baust.edu.bd', displayName: 'N', role: 'nurse');
      expect(nurse.appRole, 'doctor');
    });

    test('admin is not a super admin; super admin is an admin', () {
      expect(_admin.isAdmin, isTrue);
      expect(_admin.isSuperAdmin, isFalse);
      expect(_super.isAdmin, isTrue);
      expect(_super.isSuperAdmin, isTrue);
    });

    test('admins manage students & doctors; only super admins manage admins; nobody manages super admins or self', () {
      Map<String, dynamic> u(String uid) => _users.firstWhere((e) => e['uid'] == uid);
      expect(UserAdminService.assignableRoles(_admin), ['student', 'doctor', 'pharmacist']);
      expect(UserAdminService.assignableRoles(_super), ['student', 'doctor', 'pharmacist', 'admin']);

      expect(UserAdminService.canManage(_admin, u('s1')), isTrue);
      expect(UserAdminService.canManage(_admin, u('d1')), isTrue);
      expect(UserAdminService.canManage(_admin, u('a2')), isFalse);
      expect(UserAdminService.canManage(_admin, u('sa')), isFalse);
      expect(UserAdminService.canManage(_admin, u('a1')), isFalse); // self

      expect(UserAdminService.canManage(_super, u('a2')), isTrue);
      expect(UserAdminService.canManage(_super, u('sa')), isFalse); // self / super admin
    });

    test('removed accounts are flagged', () {
      expect(UserProfile.fromFirestore('x', {'role': 'student', 'accountStatus': 'removed'}).isRemoved, isTrue);
      expect(UserProfile.fromFirestore('y', {'role': 'student'}).isRemoved, isFalse);
    });
  });

  testWidgets('admin sees users, removed filter, and can remove a student', (tester) async {
    final removed = <String>[];
    await _pump(
      tester,
      _admin,
      UserManagementScreen(
        usersStreamOverride: () => Stream.value(_users),
        onSetRemovedOverride: (u, r) async => removed.add('${u['uid']}:$r'),
      ),
    );

    expect(find.text('Sajol Hassan'), findsOneWidget);
    expect(find.text('Removed Student'), findsNothing); // hidden from active list
    expect(find.text('Nurse Rina'), findsOneWidget);

    await tester.ensureVisible(find.text('Removed (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Removed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Removed Student'), findsOneWidget);

    await tester.ensureVisible(find.text('All (6)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All (6)'));
    await tester.pumpAndSettle();

    final sajolCard = find.ancestor(of: find.text('Sajol Hassan'), matching: find.byType(Card));
    await tester.tap(find.descendant(of: sajolCard, matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    expect(find.text('Make Doctor'), findsOneWidget);
    expect(find.text('Make Admin'), findsNothing); // admins can't create admins
    await tester.tap(find.text('Remove user'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(removed, ['s1:true']);
  });

  testWidgets('admin cannot manage other admins (lock icon shown)', (tester) async {
    await _pump(tester, _admin, UserManagementScreen(usersStreamOverride: () => Stream.value(_users)));
    final adminTwoCard = find.ancestor(of: find.text('Admin Two'), matching: find.byType(Card));
    expect(find.descendant(of: adminTwoCard, matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
  });

  testWidgets('super admin can add an admin manually', (tester) async {
    Map<String, String>? created;
    await _pump(
      tester,
      _super,
      UserManagementScreen(usersStreamOverride: () => Stream.value(_users), onCreateOverride: (f) async => created = f),
    );
    await tester.tap(find.text('Add user'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Admin')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name *'), 'New Admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email *'), 'newadmin@baust.edu.bd');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(created?['role'], 'admin');
    expect(created?['email'], 'newadmin@baust.edu.bd');
    expect(created!.containsKey('password'), isFalse);
  });

  testWidgets('feedback: user submits a bug report', (tester) async {
    String? sent;
    await _pump(
      tester,
      const UserProfile(uid: 's1', email: 's@baust.edu.bd', displayName: 'S', role: 'student'),
      SendFeedbackScreen(onSubmitOverride: (type, msg) async => sent = '$type:$msg'),
    );
    await tester.enterText(find.byType(TextFormField), 'The SOS button does nothing on my phone');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent, 'bug:The SOS button does nothing on my phone');
  });

  testWidgets('feedback inbox is super-admin only', (tester) async {
    await _pump(tester, _admin, FeedbackInboxScreen(streamOverride: (_) => Stream.value(const [])));
    expect(find.text('Super admins only'), findsOneWidget);
  });

  testWidgets('super admin resolves a report', (tester) async {
    final updates = <String>[];
    await _pump(
      tester,
      _super,
      FeedbackInboxScreen(
        streamOverride: (status) => Stream.value(
          status == 'open'
              ? [
                  {'id': 'f1', 'type': 'bug', 'message': 'Crash on login', 'displayName': 'S', 'role': 'student'},
                ]
              : const [],
        ),
        onSetStatusOverride: (id, s) async => updates.add('$id:$s'),
      ),
    );
    expect(find.text('Crash on login'), findsOneWidget);
    await tester.tap(find.text('Mark resolved'));
    await tester.pumpAndSettle();
    expect(updates, ['f1:resolved']);
  });
}
