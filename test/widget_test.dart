import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:axomai_app/main.dart';

void main() {
  testWidgets('AxomAiApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AxomAiApp(initialIsDark: true));

    // Verify header and landing components load
    expect(find.text('Axom 2.0 Pro'), findsOneWidget);
    expect(find.text('Assam AI'), findsOneWidget);
  });
}
