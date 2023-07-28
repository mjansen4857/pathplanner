import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  // Basic full-app integration test for not
  // TODO: flesh this out to test app function

  testWidgets('Full app test', (widgetTester) async {
    var fs = MemoryFileSystem();

    SharedPreferences.setMockInitialValues({});
    var prefs = await SharedPreferences.getInstance();

    widgetTester.pumpWidget(PathPlanner(
      appVersion: '2077.1.0',
      fs: fs,
      prefs: prefs,
      undoStack: ChangeStack(),
    ));
  });
}
