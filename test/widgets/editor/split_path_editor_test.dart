import 'dart:math';

import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/preview_starting_state.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/path_painter.dart';
import 'package:pathplanner/widgets/editor/split_path_editor.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late PathPlannerPath path;
  late SharedPreferences prefs;
  late ChangeStack undoStack;

  setUp(() async {
    var fs = MemoryFileSystem();
    await fs.directory('/paths').create(recursive: true);
    path = PathPlannerPath.defaultPath(
      name: 'path',
      pathDir: '/paths',
      fs: fs,
    );
    path.goalEndState.rotation = 0;
    path.rotationTargets = [
      RotationTarget(waypointRelativePos: 0.5, rotationDegrees: 0),
    ];
    path.eventMarkers = [
      EventMarker(
        waypointRelativePos: 0.5,
        command: SequentialCommandGroup(commands: []),
        name: 'm',
      ),
    ];
    path.constraintZones = [
      ConstraintsZone(
        constraints: PathConstraints(),
        minWaypointRelativePos: 0.2,
        maxWaypointRelativePos: 0.8,
        name: 'z',
      ),
    ];
    undoStack = ChangeStack();
    SharedPreferences.setMockInitialValues({
      PrefsKeys.holonomicMode: true,
      PrefsKeys.treeOnRight: true,
      PrefsKeys.robotWidth: 1.0,
      PrefsKeys.robotLength: 1.0,
    });
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('has painter and tree', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
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
    expect(find.byType(PathTree), findsOneWidget);
  });

  testWidgets('swap tree side', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
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
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
        ),
      ),
    ));

    await widgetTester.dragFrom(
        widgetTester.getCenter(find.byType(SplitPathEditor)),
        const Offset(-100, 0));

    await widgetTester.pump(const Duration(seconds: 1));

    expect(prefs.getDouble(PrefsKeys.editorTreeWeight), closeTo(0.58, 0.01));

    await widgetTester.tap(find.byTooltip('Move to Other Side'));
    await widgetTester.pump();

    await widgetTester.dragFrom(
        widgetTester.getCenter(find.byType(SplitPathEditor)) +
            const Offset(100, 0),
        const Offset(-100, 0));

    await widgetTester.pump(const Duration(seconds: 1));

    expect(prefs.getDouble(PrefsKeys.editorTreeWeight), closeTo(0.5, 0.01));
  });

  testWidgets('select/deselect waypoint', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    path.waypointsExpanded = true;
    prefs.setBool(PrefsKeys.holonomicMode, false);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
        ),
      ),
    ));

    var tapLocation = PathPainterUtil.pointToPixelOffset(
            path.waypoints.first.anchor,
            PathPainter.scale,
            FieldImage.defaultField) +
        const Offset(48, 48) + // Add 48 for padding
        const Offset(-2.0, 23.0); // Some weird buffer going on

    var gesture = await widgetTester.startGesture(tapLocation,
        kind: PointerDeviceKind.mouse);

    await widgetTester.pumpAndSettle();

    expect(find.byType(NumberTextField), findsWidgets);

    await gesture.removePointer();
    await widgetTester.pump();
    gesture = await widgetTester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.mouse);
    await widgetTester.pumpAndSettle();

    expect(find.byType(NumberTextField), findsNothing);
  });

  testWidgets('double click to add waypoint', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    final fieldImage = FieldImage.official(OfficialField.chargedUp);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: fieldImage,
          undoStack: undoStack,
        ),
      ),
    ));

    var tapLocation = PathPainterUtil.pointToPixelOffset(
            const Point(1.0, 1.0), PathPainter.scale, fieldImage) +
        const Offset(48, 48) + // Add 48 for padding
        const Offset(-2.0, 23.0); // Some weird buffer going on

    await widgetTester.tapAt(tapLocation);
    await widgetTester.pump(kDoubleTapMinTime);
    await widgetTester.tapAt(tapLocation);
    await widgetTester.pumpAndSettle();

    expect(path.waypoints.length, 3);
    expect(path.waypoints.last.anchor.x, closeTo(1.0, 0.05));
    expect(path.waypoints.last.anchor.y, closeTo(1.0, 0.05));

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.waypoints.length, 2);
  });

  testWidgets('drag waypoint', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    final fieldImage = FieldImage.official(OfficialField.chargedUp);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: fieldImage,
          undoStack: undoStack,
        ),
      ),
    ));

    final startX = path.waypoints.last.anchor.x;
    final startY = path.waypoints.last.anchor.y;
    var dragLocation = PathPainterUtil.pointToPixelOffset(
            path.waypoints.last.anchor, PathPainter.scale, fieldImage) +
        const Offset(48, 48) + // Add 48 for padding
        const Offset(-2.0, 23.0); // Some weird buffer going on
    var meterPixels =
        PathPainterUtil.metersToPixels(1.0, PathPainter.scale, fieldImage);

    var gesture = await widgetTester.startGesture(dragLocation,
        kind: PointerDeviceKind.mouse);
    await widgetTester.pump();

    for (int i = 0; i < meterPixels.ceil(); i++) {
      await gesture.moveBy(const Offset(1, 0));
      await widgetTester.pump();
    }

    await gesture.up();
    await widgetTester.pumpAndSettle();

    expect(path.waypoints.last.anchor.x, closeTo(startX + 1.0, 0.05));
    expect(path.waypoints.last.anchor.y, closeTo(startY, 0.05));

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.waypoints.last.anchor.x, closeTo(startX, 0.05));
    expect(path.waypoints.last.anchor.y, closeTo(startY, 0.05));
  });

  testWidgets('drag rotation target', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    final fieldImage = FieldImage.official(OfficialField.chargedUp);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: fieldImage,
          undoStack: undoStack,
        ),
      ),
    ));

    int pointIdx =
        (path.rotationTargets[0].waypointRelativePos / pathResolution).round();
    Point targetPos = path.pathPoints[pointIdx].position;
    var dragLocation = PathPainterUtil.pointToPixelOffset(
            targetPos + const Point(0.5, 0.0), PathPainter.scale, fieldImage) +
        const Offset(48, 48) + // Add 48 for padding
        const Offset(2.0, 28.0); // Some weird buffer going on
    var halfMeterPixels =
        PathPainterUtil.metersToPixels(0.5, PathPainter.scale, fieldImage);

    var gesture = await widgetTester.startGesture(dragLocation,
        kind: PointerDeviceKind.mouse);
    await widgetTester.pump();

    for (int i = 0; i <= halfMeterPixels.ceil(); i++) {
      await gesture.moveBy(const Offset(-1, -1.5));
      await widgetTester.pump();
    }

    await gesture.up();
    await widgetTester.pumpAndSettle();

    expect(path.rotationTargets[0].rotationDegrees, closeTo(90, 1.0));

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.rotationTargets[0].rotationDegrees, closeTo(0, 0.1));
  });

  testWidgets('drag end rotation', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    final fieldImage = FieldImage.official(OfficialField.chargedUp);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: fieldImage,
          undoStack: undoStack,
        ),
      ),
    ));

    Point targetPos = path.waypoints.last.anchor;
    var dragLocation = PathPainterUtil.pointToPixelOffset(
            targetPos + const Point(0.5, 0.0), PathPainter.scale, fieldImage) +
        const Offset(48, 48) + // Add 48 for padding
        const Offset(2.0, 28.0); // Some weird buffer going on
    var halfMeterPixels =
        PathPainterUtil.metersToPixels(0.5, PathPainter.scale, fieldImage);

    var gesture = await widgetTester.startGesture(dragLocation,
        kind: PointerDeviceKind.mouse);
    await widgetTester.pump();

    for (int i = 0; i <= halfMeterPixels.ceil(); i++) {
      await gesture.moveBy(const Offset(-1, -1.5));
      await widgetTester.pump();
    }

    await gesture.up();
    await widgetTester.pumpAndSettle();

    expect(path.goalEndState.rotation, closeTo(90, 1.0));

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.goalEndState.rotation, closeTo(0, 0.1));
  });

  testWidgets('drag preview starting state rotation', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    path.previewStartingState = PreviewStartingState();
    final fieldImage = FieldImage.official(OfficialField.chargedUp);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: fieldImage,
          undoStack: undoStack,
        ),
      ),
    ));

    Point targetPos = path.waypoints.first.anchor;
    var dragLocation = PathPainterUtil.pointToPixelOffset(
            targetPos + const Point(0.5, 0.0), PathPainter.scale, fieldImage) +
        const Offset(48, 48) + // Add 48 for padding
        const Offset(2.0, 28.0); // Some weird buffer going on
    var halfMeterPixels =
        PathPainterUtil.metersToPixels(0.5, PathPainter.scale, fieldImage);

    var gesture = await widgetTester.startGesture(dragLocation,
        kind: PointerDeviceKind.mouse);
    await widgetTester.pump();

    for (int i = 0; i <= halfMeterPixels.ceil(); i++) {
      await gesture.moveBy(const Offset(-1, -1.5));
      await widgetTester.pump();
    }

    await gesture.up();
    await widgetTester.pumpAndSettle();

    expect(path.previewStartingState!.rotation, closeTo(90, 1.0));

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.previewStartingState!.rotation, closeTo(0, 0.1));
  });

  testWidgets('delete waypoint', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    path.waypointsExpanded = true;
    path.addWaypoint(const Point(7.0, 4.0));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
        ),
      ),
    ));

    final deleteButtons = find.byTooltip('Delete Waypoint');

    expect(deleteButtons, findsNWidgets(3));

    PathPlannerPath oldPath = path.duplicate(path.name);

    await widgetTester.tap(deleteButtons.at(1));
    await widgetTester.pumpAndSettle();

    expect(path.waypoints.length, 2);

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.waypoints.length, 3);
    expect(path, oldPath);
  });

  testWidgets('hover waypoint', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    path.waypointsExpanded = true;
    path.addWaypoint(const Point(7.0, 4.0));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(widgetTester.getCenter(find.text('Waypoint 1')));
    await widgetTester.pump();

    // nothing to test here, just covering the hover code
  });

  testWidgets('hover/select constraints zone', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    path.constraintZonesExpanded = true;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    final zoneCard = find.descendant(
        of: find.byType(TreeCardNode),
        matching: find.widgetWithText(TreeCardNode, 'z'));

    await gesture.moveTo(widgetTester.getCenter(zoneCard));
    await widgetTester.pumpAndSettle();

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(zoneCard);
    await widgetTester.pumpAndSettle();

    // nothing to test here, just covering the hover/select code
  });

  testWidgets('hover/select rotation target', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    path.rotationTargetsExpanded = true;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    final targetCard = find.descendant(
        of: find.byType(TreeCardNode),
        matching: find.widgetWithText(TreeCardNode, 'Rotation Target at 0.50'));

    await gesture.moveTo(widgetTester.getCenter(targetCard));
    await widgetTester.pump();

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    await widgetTester.tap(targetCard);
    await widgetTester.pumpAndSettle();

    // nothing to test here, just covering the hover/select code
  });

  testWidgets('hover/select event marker', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    path.eventMarkersExpanded = true;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SplitPathEditor(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          undoStack: undoStack,
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    final markerCard = find.descendant(
        of: find.byType(TreeCardNode),
        matching: find.widgetWithText(TreeCardNode, 'm'));

    await gesture.moveTo(widgetTester.getCenter(markerCard));
    await widgetTester.pump();

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    await widgetTester.tap(markerCard);
    await widgetTester.pumpAndSettle();

    // nothing to test here, just covering the hover/select code
  });
}
