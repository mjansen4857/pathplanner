import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/pages/home_page.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file/memory.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/services/update_checker.dart';
import 'package:undo/undo.dart';

void main() {
  late SharedPreferences prefs;
  late MemoryFileSystem fs;
  late ChangeStack undoStack;
  late PPLibTelemetry telemetry;
  late UpdateChecker updateChecker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fs = MemoryFileSystem();
    undoStack = ChangeStack();
    telemetry = PPLibTelemetry(serverBaseAddress: 'localhost');
    updateChecker = UpdateChecker();
  });

  testWidgets('HomePage initial rendering', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        appVersion: '1.0.0',
        prefs: prefs,
        onTeamColorChanged: (_) {},
        fs: fs,
        undoStack: undoStack,
        telemetry: telemetry,
        updateChecker: updateChecker,
      ),
    ));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(CustomAppBar), findsOneWidget);
    expect(find.text('PathPlanner'), findsOneWidget);
  });
}
