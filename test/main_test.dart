import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pathplanner/main.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'package:mockito/annotations.dart';

import 'main_test.mocks.dart';

@GenerateNiceMocks([MockSpec<PPLibTelemetry>()])
void main() {
  // Basic full-app integration test for not
  // TODO: flesh this out to test app function

  testWidgets('Full app test', (widgetTester) async {
    var fs = MemoryFileSystem();
    var undoStack = ChangeStack();
    var telemetry = MockPPLibTelemetry();

    SharedPreferences.setMockInitialValues({});
    var prefs = await SharedPreferences.getInstance();

    when(telemetry.isConnected).thenReturn(true);
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => Stream.value(true));

    widgetTester.pumpWidget(PathPlanner(
      appVersion: '2077.1.0',
      fs: fs,
      prefs: prefs,
      undoStack: undoStack,
      telemetry: telemetry,
    ));
  });
}
