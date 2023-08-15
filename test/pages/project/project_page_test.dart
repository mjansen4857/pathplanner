import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_auto_editor.dart';
import 'package:pathplanner/widgets/editor/split_path_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

import '../../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late MemoryFileSystem fs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.projectLeftWeight: 0.5,
      PrefsKeys.pathFolders: ['p'],
      PrefsKeys.autoFolders: ['a'],
    });
    prefs = await SharedPreferences.getInstance();
    fs = MemoryFileSystem();
  });

  testWidgets('initially loading', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ProjectItemCard), findsNothing);
  });

  testWidgets('loads empty project', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ProjectItemCard), findsOneWidget);
    expect(
        find.widgetWithText(ProjectItemCard, 'Example Path'), findsOneWidget);
  });

  testWidgets('loads populated project', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory('/deploy/paths').create(recursive: true);
    await fs.directory('/deploy/autos').create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: '/deploy/paths',
      fs: fs,
      name: 'path1',
    );
    PathPlannerPath path2 = PathPlannerPath.defaultPath(
      pathDir: '/deploy/paths',
      fs: fs,
      name: 'path2',
    );
    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          PathCommand(pathName: 'path2'),
        ],
      ),
      autoDir: '/deploy/autos',
      fs: fs,
      folder: null,
      startingPose: null,
    );

    await fs
        .file('/deploy/paths/path1.path')
        .writeAsString(jsonEncode(path1.toJson()));
    await fs
        .file('/deploy/paths/path2.path')
        .writeAsString(jsonEncode(path2.toJson()));
    await fs
        .file('/deploy/autos/auto1.auto')
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ProjectItemCard), findsNWidgets(3));
    expect(find.widgetWithText(ProjectItemCard, 'path1'), findsOneWidget);
    expect(find.widgetWithText(ProjectItemCard, 'path2'), findsOneWidget);
    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsOneWidget);
  });

  testWidgets('loads populated project w/ bad file contents',
      (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory('/deploy/paths').create(recursive: true);
    await fs.directory('/deploy/autos').create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: '/deploy/paths',
      fs: fs,
      name: 'path1',
    );
    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          PathCommand(pathName: 'path2'),
        ],
      ),
      autoDir: '/deploy/autos',
      fs: fs,
      folder: null,
      startingPose: null,
    );

    await fs
        .file('/deploy/paths/path1.path')
        .writeAsString(jsonEncode(path1.toJson()));
    await fs
        .file('/deploy/paths/path2.path')
        .writeAsString('{{invalid json..[]}.');
    await fs
        .file('/deploy/autos/auto1.auto')
        .writeAsString(jsonEncode(auto1.toJson()));
    await fs
        .file('/deploy/autos/auto2.auto')
        .writeAsString('{{invalid json..[]}.');

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ProjectItemCard), findsNWidgets(2));
    expect(find.widgetWithText(ProjectItemCard, 'path1'), findsOneWidget);
    expect(find.widgetWithText(ProjectItemCard, 'path2'), findsNothing);
    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsOneWidget);
    expect(find.widgetWithText(ProjectItemCard, 'auto2'), findsNothing);
  });

  testWidgets('add new path button', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final addButton = find.byTooltip('Add new path');

    expect(addButton, findsOneWidget);

    await widgetTester.tap(addButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(ProjectItemCard), findsNWidgets(2));
    expect(find.widgetWithText(ProjectItemCard, 'New Path'), findsOneWidget);

    await widgetTester.tap(addButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(ProjectItemCard), findsNWidgets(3));
    expect(
        find.widgetWithText(ProjectItemCard, 'New New Path'), findsOneWidget);
  });

  testWidgets('add new auto button', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final addButton = find.byTooltip('Add new auto');

    expect(addButton, findsOneWidget);

    await widgetTester.tap(addButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(ProjectItemCard), findsNWidgets(2));
    expect(find.widgetWithText(ProjectItemCard, 'New Auto'), findsOneWidget);

    await widgetTester.tap(addButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(ProjectItemCard), findsNWidgets(3));
    expect(
        find.widgetWithText(ProjectItemCard, 'New New Auto'), findsOneWidget);
  });

  testWidgets('duplicate path', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final menuButton = find.descendant(
        of: find.widgetWithText(ProjectItemCard, 'Example Path'),
        matching: find.byType(PopupMenuButton<String>));

    expect(menuButton, findsOneWidget);

    await widgetTester.tap(menuButton);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Duplicate'));
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'Copy of Example Path'),
        findsOneWidget);

    await widgetTester.tap(menuButton);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Duplicate'));
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'Copy of Copy of Example Path'),
        findsOneWidget);
  });

  testWidgets('duplicate auto', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory('/deploy/autos').create(recursive: true);
    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          PathCommand(pathName: 'path2'),
        ],
      ),
      autoDir: '/deploy/autos',
      fs: fs,
      folder: null,
      startingPose: null,
    );

    await fs
        .file('/deploy/autos/auto1.auto')
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final menuButton = find.descendant(
        of: find.widgetWithText(ProjectItemCard, 'auto1'),
        matching: find.byType(PopupMenuButton<String>));

    expect(menuButton, findsOneWidget);

    await widgetTester.tap(menuButton);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Duplicate'));
    await widgetTester.pumpAndSettle();

    expect(
        find.widgetWithText(ProjectItemCard, 'Copy of auto1'), findsOneWidget);

    await widgetTester.tap(menuButton);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Duplicate'));
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'Copy of Copy of auto1'),
        findsOneWidget);
  });

  testWidgets('delete path', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final menuButton = find.descendant(
        of: find.widgetWithText(ProjectItemCard, 'Example Path'),
        matching: find.byType(PopupMenuButton<String>));

    expect(menuButton, findsOneWidget);

    await widgetTester.tap(menuButton);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Delete'));
    await widgetTester.pumpAndSettle();

    final confirmButton = find.text('DELETE');
    await widgetTester.tap(confirmButton);
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'Example Path'), findsNothing);
  });

  testWidgets('delete auto', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory('/deploy/autos').create(recursive: true);
    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          PathCommand(pathName: 'path2'),
        ],
      ),
      autoDir: '/deploy/autos',
      fs: fs,
      folder: null,
      startingPose: null,
    );

    await fs
        .file('/deploy/autos/auto1.auto')
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final menuButton = find.descendant(
        of: find.widgetWithText(ProjectItemCard, 'auto1'),
        matching: find.byType(PopupMenuButton<String>));

    expect(menuButton, findsOneWidget);

    await widgetTester.tap(menuButton);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Delete'));
    await widgetTester.pumpAndSettle();

    final confirmButton = find.text('DELETE');
    await widgetTester.tap(confirmButton);
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsNothing);
  });

  testWidgets('rename path', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory('/deploy/paths').create(recursive: true);
    await fs.directory('/deploy/autos').create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: '/deploy/paths',
      fs: fs,
      name: 'path1',
    );
    PathPlannerPath path2 = PathPlannerPath.defaultPath(
      pathDir: '/deploy/paths',
      fs: fs,
      name: 'path2',
    );
    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      autoDir: '/deploy/autos',
      fs: fs,
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
        ],
      ),
      folder: null,
      startingPose: null,
    );

    await fs
        .file('/deploy/paths/path1.path')
        .writeAsString(jsonEncode(path1.toJson()));
    await fs
        .file('/deploy/paths/path2.path')
        .writeAsString(jsonEncode(path2.toJson()));
    await fs
        .file('/deploy/autos/auto1.auto')
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester.enterText(find.text('path1'), 'path2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    // expect failure to rename
    expect(find.byType(AlertDialog), findsOneWidget);

    await widgetTester.tap(find.text('OK'));
    await widgetTester.pumpAndSettle();

    await widgetTester.enterText(find.text('path1'), 'path3');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('path3'), findsOneWidget);
  });

  testWidgets('rename auto', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory('/deploy/autos').create(recursive: true);

    PathPlannerAuto auto1 = PathPlannerAuto.defaultAuto(
      autoDir: '/deploy/autos',
      fs: fs,
      name: 'auto1',
    );
    PathPlannerAuto auto2 = PathPlannerAuto.defaultAuto(
      autoDir: '/deploy/autos',
      fs: fs,
      name: 'auto2',
    );

    await fs
        .file('/deploy/autos/auto1.auto')
        .writeAsString(jsonEncode(auto1.toJson()));
    await fs
        .file('/deploy/autos/auto2.auto')
        .writeAsString(jsonEncode(auto2.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester.enterText(find.text('auto1'), 'auto2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    // expect failure to rename
    expect(find.byType(AlertDialog), findsOneWidget);

    await widgetTester.tap(find.text('OK'));
    await widgetTester.pumpAndSettle();

    await widgetTester.enterText(find.text('auto1'), 'auto3');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('auto3'), findsOneWidget);
  });

  testWidgets('open path', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory('/deploy/paths').create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: '/deploy/paths',
      fs: fs,
      name: 'path1',
    );

    await fs
        .file('/deploy/paths/path1.path')
        .writeAsString(jsonEncode(path1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.widgetWithText(ProjectItemCard, 'path1'));
    await widgetTester.pumpAndSettle();

    expect(find.byType(SplitPathEditor), findsOneWidget);

    final nameField = find.descendant(
        of: find.byType(CustomAppBar), matching: find.text('path1'));
    expect(nameField, findsOneWidget);

    await widgetTester.enterText(nameField, 'path2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.byType(BackButton));
    await widgetTester.pumpAndSettle();

    expect(find.byType(SplitPathEditor), findsNothing);
    expect(find.text('path2'), findsOneWidget);
  });

  testWidgets('open auto', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory('/deploy/autos').create(recursive: true);

    PathPlannerAuto auto1 = PathPlannerAuto.defaultAuto(
      autoDir: '/deploy/autos',
      fs: fs,
      name: 'auto1',
    );

    await fs
        .file('/deploy/autos/auto1.auto')
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.widgetWithText(ProjectItemCard, 'auto1'));
    await widgetTester.pumpAndSettle();

    expect(find.byType(SplitAutoEditor), findsOneWidget);

    final nameField = find.descendant(
        of: find.byType(CustomAppBar), matching: find.text('auto1'));
    expect(nameField, findsOneWidget);

    await widgetTester.enterText(nameField, 'auto2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.byType(BackButton));
    await widgetTester.pumpAndSettle();

    expect(find.byType(SplitAutoEditor), findsNothing);
    expect(find.text('auto2'), findsOneWidget);
  });

  testWidgets('resize columns', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester.dragFrom(
        widgetTester.getCenter(find.byType(ProjectPage)),
        const Offset(-200, 0));

    await widgetTester.pump(const Duration(seconds: 1));

    expect(prefs.getDouble(PrefsKeys.projectLeftWeight), closeTo(0.35, 0.01));

    await widgetTester.dragFrom(
        widgetTester.getCenter(find.byType(ProjectPage)) +
            const Offset(-200, 0),
        const Offset(400, 0));

    await widgetTester.pump(const Duration(seconds: 1));

    expect(prefs.getDouble(PrefsKeys.projectLeftWeight), closeTo(0.65, 0.01));

    await widgetTester.dragFrom(
        widgetTester.getCenter(find.byType(ProjectPage)) + const Offset(200, 0),
        const Offset(-200, 0));

    await widgetTester.pump(const Duration(seconds: 1));

    expect(prefs.getDouble(PrefsKeys.projectLeftWeight), closeTo(0.5, 0.01));
  });

  testWidgets('shows folders', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    expect(
        find.widgetWithText(DragTarget<PathPlannerPath>, 'p'), findsOneWidget);
    expect(
        find.widgetWithText(DragTarget<PathPlannerAuto>, 'a'), findsOneWidget);
  });
}
