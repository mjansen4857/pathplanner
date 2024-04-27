import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/pages/auto_editor_page.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/simulator/trajectory_generator.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/widgets/editor/split_auto_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late PathPlannerAuto auto;
  late PathPlannerPath testPath;
  late ChoreoPath testChoreoPath;
  late ChangeStack undoStack;
  late SharedPreferences prefs;
  String? name;

  setUp(() async {
    final fs = MemoryFileSystem();
    await fs.directory('/autos').create();
    auto = PathPlannerAuto.defaultAuto(autoDir: '/autos', fs: fs);
    testPath = PathPlannerPath.defaultPath(
        pathDir: '/paths', fs: fs, name: 'testPath');
    testChoreoPath = ChoreoPath(
      name: 'test',
      trajectory: Trajectory(states: [
        TrajectoryState(time: 0.0),
        TrajectoryState(time: 1.0),
      ]),
      fs: fs,
      choreoDir: '/choreo',
      eventMarkerTimes: [0.5],
    );
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
        allChoreoPaths: [testChoreoPath],
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
        allChoreoPaths: [testChoreoPath],
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
        allChoreoPaths: [testChoreoPath],
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

  testWidgets('choreo auto sets start pose', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    auto.choreoAuto = true;
    auto.sequence = SequentialCommandGroup(commands: [
      PathCommand(pathName: 'test'),
    ]);
    await widgetTester.pumpWidget(MaterialApp(
      home: AutoEditorPage(
        prefs: prefs,
        auto: auto,
        allPaths: [testPath],
        allChoreoPaths: [testChoreoPath],
        allPathNames: const ['test'],
        fieldImage: FieldImage.defaultField,
        onRenamed: (value) => name = value,
        undoStack: undoStack,
        shortcuts: false,
      ),
    ));

    await widgetTester.tap(find.text('Starting Pose'));
    await widgetTester.pump(const Duration(seconds: 1));
    await widgetTester.pump(const Duration(seconds: 1));

    final check = find.byType(Checkbox);
    expect(check, findsOneWidget);

    await widgetTester.tap(find.byType(Checkbox));
    await widgetTester.pump(const Duration(seconds: 1));

    expect(auto.startingPose, Pose2d());
  });
}
