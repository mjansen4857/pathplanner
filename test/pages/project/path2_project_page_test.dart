import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pathplanner/pages/project/path2_project_page.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/pathplanner_auto.dart';
import 'package:pathplanner/services/project_condition_registry.dart';
import 'package:pathplanner/services/project_event_registry.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/path2/waypoint.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late MemoryFileSystem fs;
  final deployPath = Platform.isWindows ? r'C:\deploy' : '/deploy';

  setUp(() async {
    ProjectConditionRegistry.clear();
    ProjectEventRegistry.clear();
    SharedPreferences.setMockInitialValues({
      PrefsKeys.projectLeftWeight: 0.5,
      PrefsKeys.pathsCompactView: true,
    });
    prefs = await SharedPreferences.getInstance();
    fs = MemoryFileSystem(
      style: Platform.isWindows
          ? FileSystemStyle.windows
          : FileSystemStyle.posix,
    );
  });

  Widget project() => MaterialApp(
    home: Scaffold(
      body: Path2ProjectPage(
        prefs: prefs,
        fieldImage: FieldImage.defaultField,
        pathplannerDirectory: fs.directory(deployPath),
        fs: fs,
        undoStack: ChangeStack(),
        shortcuts: false,
      ),
    ),
  );

  Future<void> pumpProject(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(project());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'project defaults are saved into waypoint fields and update only default waypoints',
    (tester) async {
      final directory = fs.directory(join(deployPath, 'paths'))
        ..createSync(recursive: true);
      final path = path2.Path.defaultPath(
        name: 'Limits',
        pathDir: directory.path,
        fs: fs,
      );
      path.nodes.last.waypoint
        ..useDefaultConstraints = false
        ..maxVelocity = 1.25;
      path.saveFile();
      await prefs.setDouble(PrefsKeys.defaultMaxVel, 2.5);
      await prefs.setDouble(PrefsKeys.defaultMaxAngVel, 180);
      await prefs.setDouble(PrefsKeys.defaultMaxAngAccel, 360);
      await pumpProject(tester);
      Map<String, dynamic> saved() => jsonDecode(
        fs.file(join(directory.path, 'Limits.path')).readAsStringSync(),
      ) as Map<String, dynamic>;
      var data = saved();
      expect(data, isNot(contains('defaultConstraints')));
      expect(data['nodes'][0]['waypoint']['useDefaultConstraints'], isTrue);
      expect(data['nodes'][0]['waypoint']['maxVelocity'], 2.5);
      expect(data['nodes'][0]['waypoint']['maxAngularVelocity'], 180);
      expect(data['nodes'][0]['waypoint']['maxAngularAcceleration'], 360);
      expect(data['nodes'][1]['waypoint']['maxVelocity'], 1.25);
      await prefs.setDouble(PrefsKeys.defaultMaxVel, 4.5);
      Path2ProjectPage.settingsUpdated = true;
      await tester.pumpWidget(project());
      await tester.pumpAndSettle();
      data = saved();
      expect(data['nodes'][0]['waypoint']['maxVelocity'], 4.5);
      expect(data['nodes'][1]['waypoint']['maxVelocity'], 1.25);
    },
  );

  testWidgets('event manager persists rename and removal across paths', (
    tester,
  ) async {
    final directory = fs.directory(join(deployPath, 'paths'))
      ..createSync(recursive: true);
    for (final name in ['First', 'Second']) {
      final path = path2.Path.defaultPath(
        name: name,
        pathDir: directory.path,
        fs: fs,
      );
      path.nodes.first.waypoint.events = ['Intake', 'Other'];
      path.branches.first.events = [
        path2.BranchEvent(name: 'Intake', position: 0.2),
      ];
      path.saveFile();
    }
    ProjectEventRegistry.clear();
    await pumpProject(tester);
    await tester.tap(find.byTooltip('Manage Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rename event').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Event Name'),
      'Acquire',
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    for (final name in ['First', 'Second']) {
      final data = jsonDecode(
        fs.file(join(directory.path, '$name.path')).readAsStringSync(),
      ) as Map<String, dynamic>;
      final path = path2.Path.fromJson(data, name, directory.path, fs);
      expect(path.nodes.first.waypoint.events, ['Acquire', 'Other']);
      expect(path.branches.first.events, [
        path2.BranchEvent(name: 'Acquire', position: 0.2),
      ]);
    }
    await tester.tap(find.byTooltip('Remove event').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    for (final name in ['First', 'Second']) {
      final data = jsonDecode(
        fs.file(join(directory.path, '$name.path')).readAsStringSync(),
      ) as Map<String, dynamic>;
      final path = path2.Path.fromJson(data, name, directory.path, fs);
      expect(path.nodes.first.waypoint.events, ['Other']);
      expect(path.branches.first.events, isEmpty);
    }
    expect(ProjectEventRegistry.events, isNot(contains('Acquire')));
  });

  testWidgets('creates a graph example only for a physically empty directory', (
    tester,
  ) async {
    await pumpProject(tester);

    expect(
      find.widgetWithText(ProjectItemCard, 'Example Path'),
      findsOneWidget,
    );
    final file = fs.file(join(deployPath, 'paths', 'Example Path.path'));
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['version'], '2027.1');
    expect(json['nodes'], hasLength(2));
    expect(json['branches'], hasLength(1));
    expect(json, isNot(contains('waypoints')));
    expect(json, isNot(contains('eventMarkers')));
  });

  testWidgets('rejected files stay untouched and reserve their names', (
    tester,
  ) async {
    final pathsDir = fs.directory(join(deployPath, 'paths'))
      ..createSync(recursive: true);
    final autosDir = fs.directory(join(deployPath, 'autos'))
      ..createSync(recursive: true);
    final oldPath = fs.file(join(pathsDir.path, 'new path.path'));
    const oldPathSource = '{"version":"2027.0","waypoints":[]}';
    oldPath.writeAsStringSync(oldPathSource);
    final oldAuto = fs.file(join(autosDir.path, 'new auto.auto'));
    const oldAutoSource = '{"version":"2027.0","command":{}}';
    oldAuto.writeAsStringSync(oldAutoSource);

    await pumpProject(tester);

    expect(find.byType(ProjectItemCard), findsNothing);
    await tester.tap(find.byTooltip('Add new path'));
    await tester.tap(find.byTooltip('Add new auto'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ProjectItemCard, 'New New Path'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ProjectItemCard, 'New New Auto'),
      findsOneWidget,
    );
    expect(oldPath.readAsStringSync(), oldPathSource);
    expect(oldAuto.readAsStringSync(), oldAutoSource);
  });

  testWidgets('filters Choreo autos and creates an empty graph auto', (
    tester,
  ) async {
    final autosDir = fs.directory(join(deployPath, 'autos'))
      ..createSync(recursive: true);
    final choreoFile = fs.file(join(autosDir.path, 'new auto.auto'));
    const source = '{"choreoAuto":true,"version":"2026.0"}';
    choreoFile.writeAsStringSync(source);

    await pumpProject(tester);
    await tester.tap(find.byTooltip('Add new auto'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ProjectItemCard, 'New New Auto'),
      findsOneWidget,
    );
    final json = jsonDecode(
      fs.file(join(autosDir.path, 'New New Auto.auto')).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(json['nodes'], isEmpty);
    expect(json['branches'], isEmpty);
    expect(json, isNot(contains('command')));
    expect(choreoFile.readAsStringSync(), source);
  });

  testWidgets('condition manager renames and unsets path and auto branches', (
    tester,
  ) async {
    final pathsDir = fs.directory(join(deployPath, 'paths'))
      ..createSync(recursive: true);
    final path = path2.Path.defaultPath(
      pathDir: pathsDir.path,
      fs: fs,
      name: 'Condition Path',
    );
    path.branches.single.transition = ConditionTransition(
      conditionName: 'ready',
    );
    path.saveFile();

    final autosDir = fs.directory(join(deployPath, 'autos'))
      ..createSync(recursive: true);
    final first = PathAutoNode(
      pathName: path.name,
      editorPosition: const Offset(80, 80),
    );
    final second = PathAutoNode(
      pathName: path.name,
      editorPosition: const Offset(80, 300),
    );
    final auto = Path2Auto(
      name: 'Condition Auto',
      nodes: [first, second],
      branches: [
        AutoBranch(
          sourceId: first.id,
          targetId: second.id,
          transition: ConditionTransition(conditionName: 'ready'),
        ),
      ],
      autoDir: autosDir.path,
      fs: fs,
    )..saveFile();

    await pumpProject(tester);

    expect(find.byTooltip('Manage Events'), findsOneWidget);
    expect(find.byTooltip('Manage Conditions'), findsOneWidget);
    expect(ProjectConditionRegistry.conditions, contains('ready'));

    await tester.tap(find.byTooltip('Manage Conditions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rename condition'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'armed');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(ProjectConditionRegistry.conditions, contains('armed'));
    expect(ProjectConditionRegistry.conditions, isNot(contains('ready')));
    expect(
      fs.file(join(pathsDir.path, '${path.name}.path')).readAsStringSync(),
      contains('"conditionName": "armed"'),
    );
    expect(
      fs.file(join(autosDir.path, '${auto.name}.auto')).readAsStringSync(),
      contains('"conditionName": "armed"'),
    );

    await tester.tap(find.byTooltip('Remove condition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(ProjectConditionRegistry.conditions, isNot(contains('armed')));
    final pathJson = jsonDecode(
      fs.file(join(pathsDir.path, '${path.name}.path')).readAsStringSync(),
    ) as Map<String, dynamic>;
    final autoJson = jsonDecode(
      fs.file(join(autosDir.path, '${auto.name}.auto')).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(
      (pathJson['branches'] as List).single['transition']['conditionName'],
      isNull,
    );
    expect(
      (autoJson['branches'] as List).single['transition']['conditionName'],
      isNull,
    );
    final warningCard = tester.widget<ProjectItemCard>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ProjectItemCard && widget.name == 'Condition Path',
      ),
    );
    expect(warningCard.warningMessage, contains('no condition selected'));
  });

  testWidgets(
    'path rename propagates and deletion clears only matching references',
    (tester) async {
      final pathsDir = fs.directory(join(deployPath, 'paths'))
        ..createSync(recursive: true);
      final path = path2.Path.defaultPath(
        pathDir: pathsDir.path,
        fs: fs,
        name: 'Referenced Path',
      )..saveFile();
      final autosDir = fs.directory(join(deployPath, 'autos'))
        ..createSync(recursive: true);
      final auto = Path2Auto(
        name: 'Referencing Auto',
        nodes: [
          PathAutoNode(
            pathName: path.name,
            editorPosition: const Offset(80, 80),
          ),
          PathAutoNode(
            pathName: 'Still Missing',
            editorPosition: const Offset(80, 300),
          ),
        ],
        autoDir: autosDir.path,
        fs: fs,
      )..saveFile();

      await pumpProject(tester);
      await tester.enterText(find.text('Referenced Path'), 'Renamed Path');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      var autoJson = jsonDecode(
        fs.file(join(autosDir.path, '${auto.name}.auto')).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect((autoJson['nodes'] as List).first['pathName'], 'Renamed Path');
      expect((autoJson['nodes'] as List).last['pathName'], 'Still Missing');

      final pathCard = find.widgetWithText(ProjectItemCard, 'Renamed Path');
      final menu = find.descendant(
        of: pathCard,
        matching: find.byType(PopupMenuButton<String>),
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      autoJson = jsonDecode(
        fs.file(join(autosDir.path, '${auto.name}.auto')).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect((autoJson['nodes'] as List).first['pathName'], isNull);
      expect((autoJson['nodes'] as List).last['pathName'], 'Still Missing');
      expect(
        find.widgetWithText(ProjectItemCard, 'Renamed Path'),
        findsNothing,
      );
    },
  );

  testWidgets('missing path references warn without rewriting their auto', (
    tester,
  ) async {
    final autosDir = fs.directory(join(deployPath, 'autos'))
      ..createSync(recursive: true);
    final auto = Path2Auto(
      name: 'Missing Reference',
      nodes: [
        PathAutoNode(
          pathName: 'Unavailable Path',
          editorPosition: const Offset(80, 80),
        ),
      ],
      autoDir: autosDir.path,
      fs: fs,
    );
    final autoFile = fs.file(join(autosDir.path, '${auto.name}.auto'));
    final source = const JsonEncoder.withIndent('  ').convert(auto.toJson());
    autoFile.writeAsStringSync(source);

    await pumpProject(tester);

    final card = tester.widget<ProjectItemCard>(
      find.byWidgetPredicate(
        (widget) => widget is ProjectItemCard && widget.name == auto.name,
      ),
    );
    expect(card.warningMessage, contains('Unavailable Path'));
    expect(card.warningMessage, contains('missing path'));
    expect(autoFile.readAsStringSync(), source);
  });

  testWidgets('graph thumbnails use branch segments and every path leaf', (
    tester,
  ) async {
    final pathsDir = fs.directory(join(deployPath, 'paths'))
      ..createSync(recursive: true);
    final root = path2.PathNode(
      waypoint: TranslationWaypoint(position: const Translation2d(1, 1)),
      editorPosition: const Offset(80, 80),
    );
    final left = path2.PathNode(
      waypoint: TranslationWaypoint(position: const Translation2d(3, 2)),
      editorPosition: const Offset(20, 300),
    );
    final right = path2.PathNode(
      waypoint: TranslationWaypoint(position: const Translation2d(3, 6)),
      editorPosition: const Offset(300, 300),
    );
    final path = path2.Path(
      name: 'Branched Path',
      nodes: [root, left, right],
      branches: [
        path2.PathBranch(sourceId: root.id, targetId: left.id),
        path2.PathBranch(sourceId: root.id, targetId: right.id),
      ],
      pathDir: pathsDir.path,
      fs: fs,
    )..saveFile();

    final autosDir = fs.directory(join(deployPath, 'autos'))
      ..createSync(recursive: true);
    Path2Auto(
      name: 'Graph Auto',
      nodes: [
        PathAutoNode(pathName: path.name, editorPosition: const Offset(80, 80)),
      ],
      autoDir: autosDir.path,
      fs: fs,
    ).saveFile();

    await pumpProject(tester);

    final pathCard = tester.widget<ProjectItemCard>(
      find.byWidgetPredicate(
        (widget) => widget is ProjectItemCard && widget.name == 'Branched Path',
      ),
    );
    expect(pathCard.paths, hasLength(2));
    expect(pathCard.startPoints, [root.waypoint.position]);
    expect(
      pathCard.endPoints,
      unorderedEquals([left.waypoint.position, right.waypoint.position]),
    );

    final autoCard = tester.widget<ProjectItemCard>(
      find.byWidgetPredicate(
        (widget) => widget is ProjectItemCard && widget.name == 'Graph Auto',
      ),
    );
    expect(autoCard.paths, hasLength(2));
    expect(autoCard.startPoints, [root.waypoint.position]);
    expect(
      autoCard.endPoints,
      unorderedEquals([left.waypoint.position, right.waypoint.position]),
    );
  });

  testWidgets('connectivity drafts warn and Manage Events stays usable', (
    tester,
  ) async {
    final pathsDir = fs.directory(join(deployPath, 'paths'))
      ..createSync(recursive: true);
    path2.Path(
      name: 'Draft Path',
      nodes: [
        path2.PathNode(
          waypoint: TranslationWaypoint(position: const Translation2d(1, 1)),
          editorPosition: const Offset(80, 80),
        ),
        path2.PathNode(
          waypoint: TranslationWaypoint(position: const Translation2d(2, 2)),
          editorPosition: const Offset(300, 80),
        ),
      ],
      pathDir: pathsDir.path,
      fs: fs,
    ).saveFile();
    ProjectEventRegistry.events.add('Legacy Named Command');

    await pumpProject(tester);

    final card = tester.widget<ProjectItemCard>(
      find.byWidgetPredicate(
        (widget) => widget is ProjectItemCard && widget.name == 'Draft Path',
      ),
    );
    expect(card.warningMessage, contains('exactly one start node'));

    await tester.tap(find.byTooltip('Manage Events'));
    await tester.pumpAndSettle();
    expect(find.text('Legacy Named Command'), findsOneWidget);
  });
}
