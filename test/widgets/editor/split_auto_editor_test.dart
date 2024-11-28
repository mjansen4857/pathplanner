import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';
import 'package:pathplanner/widgets/editor/path_painter.dart';
import 'package:pathplanner/widgets/editor/split_auto_editor.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/auto_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/path_command_widget.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late PathPlannerAuto auto;
  late PathPlannerPath testPath;
  late SharedPreferences prefs;
  late ChangeStack undoStack;
  late MemoryFileSystem fs;

  setUp(() async {
    fs = MemoryFileSystem();
    testPath = PathPlannerPath.defaultPath(
      name: 'testPath',
      pathDir: '/paths',
      fs: fs,
    );
    testPath.rotationTargets = [
      RotationTarget(0.5, Rotation2d.fromDegrees(45)),
    ];
    testPath.eventMarkers = [
      EventMarker(
        waypointRelativePos: 0.5,
        command: SequentialCommandGroup(commands: []),
      ),
    ];
    auto = PathPlannerAuto(
      name: 'test',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'testPath'),
        ],
      ),
      resetOdom: true,
      autoDir: '/autos',
      fs: fs,
      folder: null,
      choreoAuto: false,
    );
    undoStack = ChangeStack();
    SharedPreferences.setMockInitialValues({
      PrefsKeys.holonomicMode: true,
      PrefsKeys.treeOnRight: true,
      PrefsKeys.robotWidth: 1.0,
      PrefsKeys.robotLength: 1.0,
      PrefsKeys.showStates: true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('has painter and tree', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    auto.choreoAuto = true;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitAutoEditor(
          prefs: prefs,
          auto: auto,
          autoPaths: [testPath],
          autoChoreoPaths: [
            ChoreoPath(
              name: 'test',
              trajectory: PathPlannerTrajectory.fromStates([
                TrajectoryState.pregen(0.0, const ChassisSpeeds(),
                    const Pose2d(Translation2d(), Rotation2d())),
                TrajectoryState.pregen(1.0, const ChassisSpeeds(),
                    const Pose2d(Translation2d(), Rotation2d())),
              ]),
              fs: fs,
              choreoDir: '/choreo',
              eventMarkerTimes: [0.5],
            ),
          ],
          allPathNames: const ['testPath', 'otherPath'],
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
          onAutoChanged: () {},
        ),
      ),
    ));

    var painters = find.byType(CustomPaint);
    bool foundPathPainter = false;
    for (var p in widgetTester.widgetList(painters)) {
      if ((p as CustomPaint).painter is PathPainter) {
        foundPathPainter = true;
      }
    }
    expect(foundPathPainter, true);
    expect(find.byType(AutoTree), findsOneWidget);
  });

  testWidgets('path hover', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitAutoEditor(
          prefs: prefs,
          auto: auto,
          autoPaths: [testPath],
          autoChoreoPaths: const [],
          allPathNames: const ['testPath', 'otherPath'],
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
          onAutoChanged: () {},
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    expect(find.byType(PathCommandWidget), findsOneWidget);

    await gesture
        .moveTo(widgetTester.getCenter(find.byType(PathCommandWidget)));
    await widgetTester.pump();

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();
  });

  testWidgets('swap tree side', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitAutoEditor(
          prefs: prefs,
          auto: auto,
          autoPaths: [testPath],
          autoChoreoPaths: const [],
          allPathNames: const ['testPath', 'otherPath'],
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
          onAutoChanged: () {},
        ),
      ),
    ));

    final swapButton = find.byTooltip('Move to Other Side');

    expect(swapButton, findsOneWidget);

    await widgetTester.tap(swapButton);
    await widgetTester.pump();

    expect(prefs.getBool(PrefsKeys.treeOnRight), false);

    await widgetTester.tap(swapButton);
    await widgetTester.pump();

    expect(prefs.getBool(PrefsKeys.treeOnRight), true);
  });

  testWidgets('change tree size', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitAutoEditor(
          prefs: prefs,
          auto: auto,
          autoPaths: [testPath],
          autoChoreoPaths: const [],
          allPathNames: const ['testPath', 'otherPath'],
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
          onAutoChanged: () {},
        ),
      ),
    ));

    await widgetTester.dragFrom(
        widgetTester.getCenter(find.byType(SplitAutoEditor)),
        const Offset(-100, 0));

    await widgetTester.pump(const Duration(seconds: 1));

    expect(prefs.getDouble(PrefsKeys.editorTreeWeight), closeTo(0.58, 0.01));

    await widgetTester.tap(find.byTooltip('Move to Other Side'));
    await widgetTester.pump();

    await widgetTester.dragFrom(
        widgetTester.getCenter(find.byType(SplitAutoEditor)) +
            const Offset(100, 0),
        const Offset(-100, 0));

    await widgetTester.pump(const Duration(seconds: 1));

    expect(prefs.getDouble(PrefsKeys.editorTreeWeight), closeTo(0.5, 0.01));
  });
}
