import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/pages/auto_editor_page.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/split_auto_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late PathPlannerAuto auto;
  late PathPlannerPath testPath;
  late ChangeStack undoStack;
  late SharedPreferences prefs;
  String? name;

  setUp(() async {
    final fs = MemoryFileSystem();
    auto = PathPlannerAuto.defaultAuto(autoDir: '/autos', fs: fs);
    testPath = PathPlannerPath.defaultPath(
        pathDir: '/paths', fs: fs, name: 'testPath');
    undoStack = ChangeStack();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    name = null;
  });

  testWidgets('shows editor', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: AutoEditorPage(
        prefs: prefs,
        auto: auto,
        allPaths: [testPath],
        allPathNames: const ['testPath'],
        fieldImage: FieldImage.defaultField,
        onRenamed: (value) => name = value,
        undoStack: undoStack,
        shortcuts: false,
      ),
    ));

    expect(find.byType(SplitAutoEditor), findsOneWidget);
  });

  testWidgets('rename', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: AutoEditorPage(
        prefs: prefs,
        auto: auto,
        allPaths: [testPath],
        allPathNames: const ['testPath'],
        fieldImage: FieldImage.defaultField,
        onRenamed: (value) => name = value,
        undoStack: undoStack,
        shortcuts: false,
      ),
    ));

    final nameField = find.byType(RenamableTitle);

    expect(nameField, findsOneWidget);

    await widgetTester.enterText(nameField, 'renamed');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(name, 'renamed');
  });

  testWidgets('back button', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: AutoEditorPage(
        prefs: prefs,
        auto: auto,
        allPaths: [testPath],
        allPathNames: const ['testPath'],
        fieldImage: FieldImage.defaultField,
        onRenamed: (value) => name = value,
        undoStack: undoStack,
        shortcuts: false,
      ),
    ));

    final backButton = find.byType(BackButton);

    expect(backButton, findsOneWidget);

    undoStack.add(Change(null, () => null, (oldValue) => null));

    await widgetTester.tap(backButton);
    await widgetTester.pump();

    // undo history should be cleared
    expect(undoStack.canUndo, false);
  });
}
