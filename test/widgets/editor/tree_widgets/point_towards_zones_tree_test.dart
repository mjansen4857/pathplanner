import 'dart:math';

import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/point_towards_zone.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/point_towards_zones_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:undo/undo.dart';

void main() {
  late ChangeStack undoStack;
  late PathPlannerPath path;
  late bool pathChanged;
  int? hoveredZone;
  int? selectedZone;

  setUp(() {
    undoStack = ChangeStack();
    path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.pointTowardsZonesExpanded = true;
    path.pointTowardsZones = [
      PointTowardsZone(
        fieldPosition: const Translation2d(0.5, 0.5),
        rotationOffset: const Rotation2d(),
        minWaypointRelativePos: 0.2,
        maxWaypointRelativePos: 0.7,
        name: '0',
      ),
      PointTowardsZone(
        fieldPosition: const Translation2d(1.0, 1.0),
        rotationOffset: const Rotation2d(pi),
        minWaypointRelativePos: 0.3,
        maxWaypointRelativePos: 0.8,
        name: '1',
      ),
    ];
    pathChanged = false;
    hoveredZone = null;
    selectedZone = null;
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    path.pointTowardsZonesExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNothing);

    await widgetTester.tap(find.byType(PointTowardsZonesTree));
    await widgetTester.pumpAndSettle();

    expect(path.pointTowardsZonesExpanded, true);

    await widgetTester.tap(find.text(
        'Point Towards Zones')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(path.pointTowardsZonesExpanded, false);
  });

  testWidgets('Zone card for each zone', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNWidgets(2));
  });

  testWidgets('Zone card titles', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    expect(find.widgetWithText(RenamableTitle, '0'), findsOneWidget);
    expect(find.widgetWithText(RenamableTitle, '1'), findsOneWidget);

    await widgetTester.enterText(
        find.widgetWithText(RenamableTitle, '0'), 'zone');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(path.pointTowardsZones[0].name, 'zone');

    undoStack.undo();
    await widgetTester.pump();
    expect(path.pointTowardsZones[0].name, '0');
  });

  testWidgets('Zone card hover', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    var zoneCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    await gesture.moveTo(widgetTester.getCenter(zoneCards.at(0)));
    await widgetTester.pump();

    expect(hoveredZone, 0);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredZone, isNull);
  });

  testWidgets('tapping expands/collapses zone cards', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    var zoneCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(zoneCards.at(0));
    await widgetTester.pumpAndSettle();
    expect(selectedZone, 0);
    expect(find.byType(NumberTextField), findsWidgets);

    await widgetTester.tap(zoneCards.at(1));
    await widgetTester.pump();
    expect(selectedZone, 1);

    await widgetTester.tap(zoneCards.at(1));
    await widgetTester.pumpAndSettle();
    expect(selectedZone, isNull);
  });

  testWidgets('Field pos x text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Field Position X (M)');

    expect(textField, findsOneWidget);

    num oldVal = path.pointTowardsZones[0].fieldPosition.x;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.pointTowardsZones[0].fieldPosition.x, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.pointTowardsZones[0].fieldPosition.x, oldVal);
  });

  testWidgets('Field pos y text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Field Position Y (M)');

    expect(textField, findsOneWidget);

    num oldVal = path.pointTowardsZones[0].fieldPosition.y;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.pointTowardsZones[0].fieldPosition.y, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.pointTowardsZones[0].fieldPosition.y, oldVal);
  });

  testWidgets('Rotation offset text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Rotation Offset (Deg)');

    expect(textField, findsOneWidget);

    num oldVal = path.pointTowardsZones[0].rotationOffset.degrees;

    await widgetTester.enterText(textField, '10');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(
        path.pointTowardsZones[0].rotationOffset.degrees, closeTo(10, 0.001));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.pointTowardsZones[0].rotationOffset.degrees,
        closeTo(oldVal, 0.001));
  });

  testWidgets('min pos slider', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
        ),
      ),
    ));

    var sliders = find.byType(Slider);

    expect(sliders, findsNWidgets(2));

    await widgetTester.tap(sliders.first); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(
        path.pointTowardsZones[0].minWaypointRelativePos, closeTo(0.5, 0.001));

    undoStack.undo();
    await widgetTester.pump();

    expect(
        path.pointTowardsZones[0].minWaypointRelativePos, closeTo(0.2, 0.001));
  });

  testWidgets('max pos slider', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
        ),
      ),
    ));

    var sliders = find.byType(Slider);

    expect(sliders, findsNWidgets(2));

    await widgetTester.tap(sliders.last); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(
        path.pointTowardsZones[0].maxWaypointRelativePos, closeTo(0.5, 0.001));

    undoStack.undo();
    await widgetTester.pump();

    expect(
        path.pointTowardsZones[0].maxWaypointRelativePos, closeTo(0.7, 0.001));
  });

  testWidgets('Delete zone button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
        ),
      ),
    ));

    var deleteButtons = find.byTooltip('Delete Zone');

    expect(deleteButtons, findsNWidgets(2));

    await widgetTester.tap(deleteButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.pointTowardsZones.length, 1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.pointTowardsZones.length, 2);
    expect(selectedZone, isNull);
  });

  testWidgets('move buttons hidden when zone selected', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
        ),
      ),
    ));

    var downButtons = find.byTooltip('Move Zone Down');
    var upButtons = find.byTooltip('Move Zone Up');

    expect(downButtons, findsNothing);
    expect(upButtons, findsNothing);
  });

  testWidgets('move zone down', (widgetTester) async {
    path.pointTowardsZones.add(PointTowardsZone());
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    var downButtons = find.byTooltip('Move Zone Down');

    expect(downButtons, findsNWidgets(3));

    // Can't move last zone down
    await widgetTester.tap(downButtons.last);
    await widgetTester.pump();

    expect(pathChanged, false);

    var oldOrder =
        PathPlannerPath.clonePointTowardsZones(path.pointTowardsZones);

    await widgetTester.tap(downButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.pointTowardsZones[0], oldOrder[0]);
    expect(path.pointTowardsZones[1], oldOrder[2]);
    expect(path.pointTowardsZones[2], oldOrder[1]);
  });

  testWidgets('move zone up', (widgetTester) async {
    path.pointTowardsZones.add(PointTowardsZone());
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    var upButtons = find.byTooltip('Move Zone Up');

    expect(upButtons, findsNWidgets(3));

    // Can't move first zone up
    await widgetTester.tap(upButtons.first);
    await widgetTester.pump();

    expect(pathChanged, false);

    var oldOrder =
        PathPlannerPath.clonePointTowardsZones(path.pointTowardsZones);

    await widgetTester.tap(upButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.pointTowardsZones[0], oldOrder[1]);
    expect(path.pointTowardsZones[1], oldOrder[0]);
    expect(path.pointTowardsZones[2], oldOrder[2]);
  });

  testWidgets('add new zone', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    // Find the add new zone button by its tooltip
    var newZoneButton = find.byTooltip('Add New Point Towards Zone');

    expect(newZoneButton, findsOneWidget);

    await widgetTester.tap(newZoneButton);
    await widgetTester.pump();

    expect(path.pointTowardsZones.length, 3);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.pointTowardsZones.length, 2);
  });

  testWidgets('start pos text field', (widgetTester) async {
    path.pointTowardsZones = [
      PointTowardsZone(
        minWaypointRelativePos: 0.25,
        maxWaypointRelativePos: 0.75,
      )
    ];

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          initiallySelectedZone: 0,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'Start Pos');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '0.4');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.pointTowardsZones.first.minWaypointRelativePos,
        closeTo(0.4, 0.001));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.pointTowardsZones.first.minWaypointRelativePos,
        closeTo(0.25, 0.001));
  });

  testWidgets('end pos text field', (widgetTester) async {
    path.pointTowardsZones = [
      PointTowardsZone(
        minWaypointRelativePos: 0.25,
        maxWaypointRelativePos: 0.75,
      )
    ];

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PointTowardsZonesTree(
          path: path,
          initiallySelectedZone: 0,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'End Pos');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '0.6');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.pointTowardsZones.first.maxWaypointRelativePos,
        closeTo(0.6, 0.001));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.pointTowardsZones.first.maxWaypointRelativePos,
        closeTo(0.75, 0.001));
  });
}
