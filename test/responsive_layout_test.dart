import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medi/core/theme/app_theme.dart';
import 'package:smart_medi/features/admin_portal/presentation/screens/admin_console_screen.dart';
import 'package:smart_medi/features/admin_portal/presentation/screens/feedback_screens.dart';
import 'package:smart_medi/features/admin_portal/presentation/screens/user_management_screen.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/auth_rbac/presentation/screens/student_id_verification_screen.dart';
import 'package:smart_medi/features/profile/presentation/screens/edit_profile_screen.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _MockAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

const _sizes = {
  'small phone': Size(320, 640),
  'phone': Size(390, 844),
  'tablet': Size(820, 1180),
  'desktop': Size(1440, 900),
};

const _student = UserProfile(
  uid: 's1',
  email: 'sajol@baust.edu.bd',
  displayName: 'MD. Sajol Hassan',
  role: 'student',
  studentRoll: '0802420205101137',
  idVerificationStatus: 'not_submitted',
);
const _super = UserProfile(uid: 'sa', email: 'super@baust.edu.bd', displayName: 'Super Admin', role: 'superadmin');

final _users = [
  {'uid': 's1', 'displayName': 'MD. Sajol Hassan', 'email': 'sajol@baust.edu.bd', 'role': 'student', 'studentRoll': '0802420205101137'},
  {'uid': 'd1', 'displayName': 'Dr. Fowzia Jahan', 'email': 'doctor@baust.edu.bd', 'role': 'doctor'},
];

void main() {
  final screens = <String, (UserProfile, Widget Function())>{
    'Edit profile': (_student, () => const EditProfileScreen()),
    'Student ID verification': (_student, () => const StudentIdVerificationScreen(watchReview: false)),
    'Admin console': (_super, () => AdminConsoleScreen(usersStreamOverride: () => Stream.value(_users))),
    'User management': (_super, () => UserManagementScreen(usersStreamOverride: () => Stream.value(_users))),
    'Send feedback': (_student, () => const SendFeedbackScreen()),
  };

  for (final screen in screens.entries) {
    for (final size in _sizes.entries) {
      testWidgets('${screen.key} has no overflow on ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _MockAuthNotifier(AuthState(status: AuthStatus.authenticated, userProfile: screen.value.$1)),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: screen.value.$2()),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
