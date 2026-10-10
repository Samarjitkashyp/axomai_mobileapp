import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:axomai_app/main.dart';

void main() {
  testWidgets('AxomAiApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AxomAiApp(initialIsDark: true));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AxomAiApp), findsOneWidget);
  });
}
