import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_medi/app.dart';

void main() {
  testWidgets('SmartMediApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartMediApp(),
      ),
    );
  });
}
