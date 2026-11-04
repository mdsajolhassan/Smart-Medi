import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medi/features/medical_operations/presentation/widgets/student_department_directory.dart';

/// Widget tests for [StudentDepartmentDirectory] (Issue #3 acceptance criteria):
///   1. Accordion UI categorized by department, with CSE first and expanded.
///   2. Students grouped into their department, including fuzzy normalization.
///   3. Empty states shown when a (visible) department has no students.
/// These exercise the deterministic `studentsOverride` path, so no live
/// Firestore connection is required.
void main() {
  // Number of canonical departments rendered by the widget (CSE, EEE, ME, CE,
  // ICT, IPE, DBA, English). Kept in sync with the widget's internal list.
  const canonicalDepartmentCount = 8;

  // Pumps the directory inside a scrollable Scaffold on a tall surface so the
  // full accordion renders without vertical overflow in the test harness.
  Future<void> pumpDirectory(
    WidgetTester tester, {
    required List<Map<String, dynamic>> students,
    void Function(Map<String, dynamic> data, String uid)? onSelected,
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentDepartmentDirectory(
              studentsOverride: students,
              onStudentSelected: onSelected ?? (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('StudentDepartmentDirectory — Issue #3', () {
    testWidgets('renders every canonical department as an ExpansionTile',
        (tester) async {
      await pumpDirectory(tester, students: const []);

      // One accordion per canonical department.
      expect(
        find.byType(ExpansionTile),
        findsNWidgets(canonicalDepartmentCount),
      );
      expect(
        find.text('Computer Science & Engineering (CSE)'),
        findsOneWidget,
      );
      expect(
        find.text('Electrical & Electronic Engineering (EEE)'),
        findsOneWidget,
      );
    });

    testWidgets('places CSE first and expands it by default', (tester) async {
      await pumpDirectory(tester, students: const []);

      final cseOffset = tester.getTopLeft(
        find.text('Computer Science & Engineering (CSE)'),
      );
      final eeeOffset = tester.getTopLeft(
        find.text('Electrical & Electronic Engineering (EEE)'),
      );

      // CSE header sits above EEE header → CSE is first.
      expect(cseOffset.dy, lessThan(eeeOffset.dy));

      // CSE is the initially-expanded tile, so its empty-state body is in the
      // tree while collapsed departments' bodies are not.
      expect(find.text('No students registered yet'), findsOneWidget);
    });

    testWidgets('shows an empty state inside the expanded CSE department',
        (tester) async {
      await pumpDirectory(tester, students: const []);

      expect(find.text('No students registered yet'), findsOneWidget);
      expect(
        find.text('Students will appear here upon onboarding completion.'),
        findsOneWidget,
      );
      // Every department reports a zero count while empty.
      expect(find.text('0 registered students'), findsWidgets);
    });

    testWidgets('groups students into their department and counts them',
        (tester) async {
      await pumpDirectory(tester, students: const [
        {
          'uid': 's1',
          'displayName': 'Sajol Hassan',
          'studentId': 'CSE-001',
          'department': 'Computer Science & Engineering (CSE)',
        },
        {
          'uid': 's2',
          'displayName': 'Rahim Uddin',
          'studentId': 'CSE-002',
          'department': 'cse', // fuzzy value → normalized to CSE
        },
        {
          'uid': 's3',
          'displayName': 'Karim Ali',
          'studentId': 'EEE-001',
          'department': 'Electrical',
        },
      ]);

      // Counts reflect normalized grouping: 2 in CSE, 1 in EEE.
      expect(find.text('2 registered students'), findsOneWidget);
      expect(find.text('1 registered student'), findsOneWidget);

      // CSE is expanded, so its students are visible...
      expect(find.text('Sajol Hassan'), findsOneWidget);
      expect(find.text('Rahim Uddin'), findsOneWidget);
      // ...while the collapsed EEE department's student is not yet in the tree.
      expect(find.text('Karim Ali'), findsNothing);
    });

    testWidgets('invokes onStudentSelected with the student uid on tap',
        (tester) async {
      Map<String, dynamic>? tappedData;
      String? tappedUid;

      await pumpDirectory(
        tester,
        students: const [
          {
            'uid': 'student-xyz',
            'displayName': 'Sajol Hassan',
            'studentId': 'CSE-001',
            'department': 'Computer Science & Engineering (CSE)',
          },
        ],
        onSelected: (data, uid) {
          tappedData = data;
          tappedUid = uid;
        },
      );

      await tester.tap(find.text('Sajol Hassan'));
      await tester.pumpAndSettle();

      expect(tappedUid, 'student-xyz');
      expect(tappedData?['displayName'], 'Sajol Hassan');
    });

    testWidgets('expanding a collapsed department reveals its empty state',
        (tester) async {
      await pumpDirectory(tester, students: const []);

      // EEE starts collapsed → its body is absent.
      expect(find.text('No students registered yet'), findsOneWidget);

      await tester.tap(find.text('Electrical & Electronic Engineering (EEE)'));
      await tester.pumpAndSettle();

      // Now both CSE and EEE show the empty-state card.
      expect(find.text('No students registered yet'), findsNWidgets(2));
    });
  });
}
