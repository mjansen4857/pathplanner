import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/error_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('error popup', (widgetTester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await widgetTester.pumpWidget(ErrorPopup(
      prefs: prefs,
      error: 'Test Error',
      stackTrace: StackTrace.fromString('Test stack trace'),
    ));

    expect(find.text('Test Error'), findsOne);
    expect(find.text('Copy Stack Trace'), findsOne);
    expect(find.text('Report Issue'), findsOne);
  });
}
