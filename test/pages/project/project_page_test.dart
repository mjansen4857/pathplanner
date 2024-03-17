import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/pages/choreo_path_editor_page.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
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
  final String deployPath = Platform.isWindows ? 'C:\\deploy' : '/deploy';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.projectLeftWeight: 0.5,
      PrefsKeys.pathFolders: ['p'],
      PrefsKeys.autoFolders: ['a'],
    });
    prefs = await SharedPreferences.getInstance();
    fs = MemoryFileSystem(
        style: Platform.isWindows
            ? FileSystemStyle.windows
            : FileSystemStyle.posix);
  });

  testWidgets('initially loading', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);
    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
      name: 'path1',
    );
    PathPlannerPath path2 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
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
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      folder: null,
      startingPose: null,
      choreoAuto: false,
    );

    await fs
        .file(join(deployPath, 'paths', 'path1.path'))
        .writeAsString(jsonEncode(path1.toJson()));
    await fs
        .file(join(deployPath, 'paths', 'path2.path'))
        .writeAsString(jsonEncode(path2.toJson()));
    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);
    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
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
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      folder: null,
      startingPose: null,
      choreoAuto: false,
    );

    await fs
        .file(join(deployPath, 'paths', 'path1.path'))
        .writeAsString(jsonEncode(path1.toJson()));
    await fs
        .file(join(deployPath, 'paths', 'path2.path'))
        .writeAsString('{{invalid json..[]}.');
    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));
    await fs
        .file(join(deployPath, 'autos', 'auto2.auto'))
        .writeAsString('{{invalid json..[]}.');

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

  testWidgets('add new auto button w/ choreo', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory(join(deployPath, 'choreo')).create(recursive: true);
    await fs
        .file(join(deployPath, 'choreo', 'test.traj'))
        .writeAsString(jsonEncode({
          'samples': [
            {
              'timestamp': 0.0,
              'x': 0.0,
              'y': 0.0,
              'heading': 0.0,
            },
            {
              'timestamp': 1.0,
              'x': 1.0,
              'y': 1.0,
              'heading': 0.0,
            },
          ],
        }));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    expect(find.text('New PathPlanner Auto'), findsWidgets);
    expect(find.text('New Choreo Auto'), findsWidgets);

    await widgetTester.tap(find.text('New Choreo Auto'));
    await widgetTester.pumpAndSettle();
  });

  testWidgets('add new auto button', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    await fs.directory(join(deployPath, 'autos')).create(recursive: true);
    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          PathCommand(pathName: 'path2'),
        ],
      ),
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      folder: null,
      startingPose: null,
      choreoAuto: false,
    );

    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    await fs.directory(join(deployPath, 'autos')).create(recursive: true);
    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          PathCommand(pathName: 'path2'),
        ],
      ),
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      folder: null,
      startingPose: null,
      choreoAuto: false,
    );

    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);
    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
      name: 'path1',
    );
    PathPlannerPath path2 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
      name: 'path2',
    );
    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
        ],
      ),
      folder: null,
      startingPose: null,
      choreoAuto: false,
    );

    await fs
        .file(join(deployPath, 'paths', 'path1.path'))
        .writeAsString(jsonEncode(path1.toJson()));
    await fs
        .file(join(deployPath, 'paths', 'path2.path'))
        .writeAsString(jsonEncode(path2.toJson()));
    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    PathPlannerAuto auto1 = PathPlannerAuto.defaultAuto(
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      name: 'auto1',
    );
    PathPlannerAuto auto2 = PathPlannerAuto.defaultAuto(
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      name: 'auto2',
    );

    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));
    await fs
        .file(join(deployPath, 'autos', 'auto2.auto'))
        .writeAsString(jsonEncode(auto2.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
      name: 'path1',
    );

    await fs
        .file(join(deployPath, 'paths', 'path1.path'))
        .writeAsString(jsonEncode(path1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    PathPlannerAuto auto1 = PathPlannerAuto.defaultAuto(
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      name: 'auto1',
    );

    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
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

  testWidgets('open path folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerPath>, 'p'));
    await widgetTester.pump();
    expect(find.widgetWithText(DragTarget<PathPlannerPath>, 'p'), findsNothing);
    expect(find.widgetWithText(DragTarget<PathPlannerPath>, 'Root Folder'),
        findsOneWidget);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerPath>, 'Root Folder'));
    await widgetTester.pump();
    expect(
        find.widgetWithText(DragTarget<PathPlannerPath>, 'p'), findsOneWidget);
    expect(find.widgetWithText(DragTarget<PathPlannerPath>, 'Root Folder'),
        findsNothing);
  });

  testWidgets('open auto folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerAuto>, 'a'));
    await widgetTester.pump();
    expect(find.widgetWithText(DragTarget<PathPlannerAuto>, 'a'), findsNothing);
    expect(find.widgetWithText(DragTarget<PathPlannerAuto>, 'Root Folder'),
        findsOneWidget);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerAuto>, 'Root Folder'));
    await widgetTester.pump();
    expect(
        find.widgetWithText(DragTarget<PathPlannerAuto>, 'a'), findsOneWidget);
    expect(find.widgetWithText(DragTarget<PathPlannerAuto>, 'Root Folder'),
        findsNothing);
  });

  testWidgets('drag to path folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    var pathOffset = widgetTester
        .getCenter(find.widgetWithText(ProjectItemCard, 'Example Path'));
    var folderOffset = widgetTester
        .getCenter(find.widgetWithText(DragTarget<PathPlannerPath>, 'p'));
    var dragOffset = folderOffset - pathOffset;

    await widgetTester.dragFrom(pathOffset, dragOffset);
    await widgetTester.pump();

    expect(find.widgetWithText(ProjectItemCard, 'Example Path'), findsNothing);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerPath>, 'p'));
    await widgetTester.pump();

    expect(
        find.widgetWithText(ProjectItemCard, 'Example Path'), findsOneWidget);

    await widgetTester.dragFrom(pathOffset, dragOffset);
    await widgetTester.pump();

    expect(find.widgetWithText(ProjectItemCard, 'Example Path'), findsNothing);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerPath>, 'Root Folder'));
    await widgetTester.pump();

    expect(
        find.widgetWithText(ProjectItemCard, 'Example Path'), findsOneWidget);
  });

  testWidgets('drag to auto folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'auto1',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          PathCommand(pathName: 'path2'),
        ],
      ),
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      folder: null,
      startingPose: null,
      choreoAuto: false,
    );

    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    var pathOffset =
        widgetTester.getCenter(find.widgetWithText(ProjectItemCard, 'auto1'));
    var folderOffset = widgetTester
        .getCenter(find.widgetWithText(DragTarget<PathPlannerAuto>, 'a'));
    var dragOffset = folderOffset - pathOffset;

    await widgetTester.dragFrom(pathOffset, dragOffset);
    await widgetTester.pump();

    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsNothing);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerAuto>, 'a'));
    await widgetTester.pump();

    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsOneWidget);

    await widgetTester.dragFrom(pathOffset, dragOffset);
    await widgetTester.pump();

    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsNothing);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerAuto>, 'Root Folder'));
    await widgetTester.pump();

    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsOneWidget);
  });

  testWidgets('add path folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    expect(find.byTooltip('Add new path folder'), findsOneWidget);

    await widgetTester.tap(find.byTooltip('Add new path folder'));
    await widgetTester.pump();

    expect(find.widgetWithText(DragTarget<PathPlannerPath>, 'New Folder'),
        findsOneWidget);
  });

  testWidgets('add auto folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    expect(find.byTooltip('Add new auto folder'), findsOneWidget);

    await widgetTester.tap(find.byTooltip('Add new auto folder'));
    await widgetTester.pump();

    expect(find.widgetWithText(DragTarget<PathPlannerAuto>, 'New Folder'),
        findsOneWidget);
  });

  testWidgets('delete path folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
      name: 'path1',
      folder: 'p',
    );

    await fs
        .file(join(deployPath, 'paths', 'path1.path'))
        .writeAsString(jsonEncode(path1.toJson()));

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerPath>, 'p'));
    await widgetTester.pump();

    expect(find.byTooltip('Delete path folder'), findsOneWidget);

    await widgetTester.tap(find.byTooltip('Delete path folder'));
    await widgetTester.pumpAndSettle();

    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('DELETE'), findsOneWidget);

    await widgetTester.tap(find.text('CANCEL'));
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'path1'), findsOneWidget);

    await widgetTester.tap(find.byTooltip('Delete path folder'));
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('DELETE'));
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'path1'), findsNothing);
  });

  testWidgets('choreo paths folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);
    await fs.directory(join(deployPath, 'choreo')).create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
      name: 'path1',
      folder: 'p',
    );

    await fs
        .file(join(deployPath, 'paths', 'path1.path'))
        .writeAsString(jsonEncode(path1.toJson()));
    await fs
        .file(join(deployPath, 'choreo', 'test.traj'))
        .writeAsString(jsonEncode({
          'samples': [
            {
              'timestamp': 0.0,
              'x': 0.0,
              'y': 0.0,
              'heading': 0.0,
            },
            {
              'timestamp': 1.0,
              'x': 1.0,
              'y': 1.0,
              'heading': 0.0,
            },
          ],
          'eventMarkers': [
            {
              'timestamp': 0.5,
            },
          ],
        }));

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final folder = find.text('Choreo Paths');
    expect(folder, findsOneWidget);

    await widgetTester.tap(folder);
    await widgetTester.pump();

    final card = find.widgetWithText(ProjectItemCard, 'test');
    expect(card, findsOneWidget);

    await widgetTester.tap(card);
    await widgetTester.pump();
    await widgetTester.pump();

    expect(find.byType(ChoreoPathEditorPage), findsOneWidget);
  });

  testWidgets('delete auto folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    PathPlannerAuto auto1 = PathPlannerAuto.defaultAuto(
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      name: 'auto1',
      folder: 'a',
    );

    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerAuto>, 'a'));
    await widgetTester.pump();

    expect(find.byTooltip('Delete auto folder'), findsOneWidget);

    await widgetTester.tap(find.byTooltip('Delete auto folder'));
    await widgetTester.pumpAndSettle();

    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('DELETE'), findsOneWidget);

    await widgetTester.tap(find.text('CANCEL'));
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsOneWidget);

    await widgetTester.tap(find.byTooltip('Delete auto folder'));
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('DELETE'));
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsNothing);
  });

  testWidgets('rename path folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    prefs.setStringList(PrefsKeys.pathFolders, ['p', 'other']);

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);

    PathPlannerPath path1 = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
      name: 'path1',
      folder: 'p',
    );

    await fs
        .file(join(deployPath, 'paths', 'path1.path'))
        .writeAsString(jsonEncode(path1.toJson()));

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester.enterText(find.text('p'), 'r');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(find.widgetWithText(DragTarget<PathPlannerPath>, 'p'), findsNothing);
    expect(
        find.widgetWithText(DragTarget<PathPlannerPath>, 'r'), findsOneWidget);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerPath>, 'r'));
    await widgetTester.pump();

    expect(find.widgetWithText(ProjectItemCard, 'path1'), findsOneWidget);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerPath>, 'Root Folder'));
    await widgetTester.pump();

    await widgetTester.enterText(find.text('other'), 'r');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(find.textContaining('Unable to Rename'), findsOneWidget);
  });

  testWidgets('rename auto folder', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    prefs.setStringList(PrefsKeys.autoFolders, ['a', 'other']);

    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    PathPlannerAuto auto1 = PathPlannerAuto.defaultAuto(
      autoDir: join(deployPath, 'autos'),
      fs: fs,
      name: 'auto1',
      folder: 'a',
    );

    await fs
        .file(join(deployPath, 'autos', 'auto1.auto'))
        .writeAsString(jsonEncode(auto1.toJson()));

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    await widgetTester.enterText(find.text('a'), 'r');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(find.widgetWithText(DragTarget<PathPlannerAuto>, 'a'), findsNothing);
    expect(
        find.widgetWithText(DragTarget<PathPlannerAuto>, 'r'), findsOneWidget);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerAuto>, 'r'));
    await widgetTester.pump();

    expect(find.widgetWithText(ProjectItemCard, 'auto1'), findsOneWidget);

    await widgetTester
        .tap(find.widgetWithText(DragTarget<PathPlannerAuto>, 'Root Folder'));
    await widgetTester.pump();

    await widgetTester.enterText(find.text('other'), 'r');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(find.textContaining('Unable to Rename'), findsOneWidget);
  });

  testWidgets('named command rename', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);
    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    Command.named.add('test1');

    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
    );
    path.eventMarkers.add(
      EventMarker(
        command: SequentialCommandGroup(
          commands: [
            ParallelCommandGroup(
              commands: [
                NamedCommand(name: 'test1'),
              ],
            ),
          ],
        ),
      ),
    );
    path.generateAndSavePath();

    PathPlannerAuto auto = PathPlannerAuto.defaultAuto(
      autoDir: join(deployPath, 'autos'),
      fs: fs,
    );
    auto.sequence.commands.add(NamedCommand(name: 'test1'));
    auto.saveFile();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);

    expect(fab, findsOneWidget);

    await widgetTester.tap(fab);
    await widgetTester.pumpAndSettle();

    final renameBtn = find.descendant(
        of: find.widgetWithText(ListTile, 'test1'),
        matching: find.byTooltip('Rename named command'));
    expect(renameBtn, findsOneWidget);

    await widgetTester.tap(renameBtn);
    await widgetTester.pumpAndSettle();

    final textField = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));

    await widgetTester.enterText(textField, 'test1renamed');
    await widgetTester.pump();

    final confirmBtn = find.text('Confirm');

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();
  });

  testWidgets('linked waypoint rename', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);
    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    Command.named.add('test1');
    Waypoint.linked['link1'] = const Point(0, 0);

    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
    );
    path.waypoints[0].linkedName = 'link1';
    path.generateAndSavePath();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);

    expect(fab, findsOneWidget);

    await widgetTester.tap(fab);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Manage Linked Waypoints'));
    await widgetTester.pumpAndSettle();

    final renameBtn = find.descendant(
        of: find.widgetWithText(ListTile, 'link1'),
        matching: find.byTooltip('Rename linked waypoint'));
    expect(renameBtn, findsOneWidget);

    await widgetTester.tap(renameBtn);
    await widgetTester.pumpAndSettle();

    final textField = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));

    await widgetTester.enterText(textField, 'link1renamed');
    await widgetTester.pump();

    final confirmBtn = find.text('Confirm');

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();
  });

  testWidgets('named command remove', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);
    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    Command.named.add('test1');

    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
    );
    path.eventMarkers.add(
      EventMarker(
        command: SequentialCommandGroup(
          commands: [
            ParallelCommandGroup(
              commands: [
                NamedCommand(name: 'test1'),
              ],
            ),
          ],
        ),
      ),
    );
    path.generateAndSavePath();

    PathPlannerAuto auto = PathPlannerAuto.defaultAuto(
      autoDir: join(deployPath, 'autos'),
      fs: fs,
    );
    auto.sequence.commands.add(NamedCommand(name: 'test1'));
    auto.saveFile();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);

    expect(fab, findsOneWidget);

    await widgetTester.tap(fab);
    await widgetTester.pumpAndSettle();

    final removeBtn = find.descendant(
        of: find.widgetWithText(ListTile, 'test1'),
        matching: find.byTooltip('Remove named command'));
    expect(removeBtn, findsOneWidget);

    await widgetTester.tap(removeBtn);
    await widgetTester.pumpAndSettle();

    final confirmBtn = find.text('Confirm');

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();
  });

  testWidgets('linked waypoint remove', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await fs.directory(join(deployPath, 'paths')).create(recursive: true);
    await fs.directory(join(deployPath, 'autos')).create(recursive: true);

    Waypoint.linked['link1'] = const Point(0, 0);

    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: join(deployPath, 'paths'),
      fs: fs,
    );
    path.waypoints[0].linkedName = 'link1';
    path.generateAndSavePath();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectPage(
          prefs: prefs,
          fieldImage: FieldImage.defaultField,
          pathplannerDirectory: fs.directory(deployPath),
          choreoDirectory: fs.directory(join(deployPath, 'choreo')),
          fs: fs,
          undoStack: ChangeStack(),
          shortcuts: false,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);

    expect(fab, findsOneWidget);

    await widgetTester.tap(fab);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Manage Linked Waypoints'));
    await widgetTester.pumpAndSettle();

    final removeBtn = find.descendant(
        of: find.widgetWithText(ListTile, 'link1'),
        matching: find.byTooltip('Remove linked waypoint'));
    expect(removeBtn, findsOneWidget);

    await widgetTester.tap(removeBtn);
    await widgetTester.pumpAndSettle();

    final confirmBtn = find.text('Confirm');

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();
  });
}
