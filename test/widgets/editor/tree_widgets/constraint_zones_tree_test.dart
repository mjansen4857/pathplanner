import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/constraint_zones_tree.dart';
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
    path.constraintZonesExpanded = true;
    path.constraintZones = [
      ConstraintsZone(
        constraints: PathConstraints(),
        minWaypointRelativePos: 0.2,
        maxWaypointRelativePos: 0.7,
        name: '0',
      ),
      ConstraintsZone(
        constraints: PathConstraints(),
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
    path.constraintZonesExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNothing);

    await widgetTester.tap(find.byType(ConstraintZonesTree));
    await widgetTester.pumpAndSettle();

    expect(path.constraintZonesExpanded, true);

    await widgetTester.tap(find.text(
        'Constraint Zones')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(path.constraintZonesExpanded, false);
  });

  testWidgets('Zone card for each zone', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          holonomicMode: true,
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
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    expect(find.widgetWithText(RenamableTitle, '0'), findsOneWidget);
    expect(find.widgetWithText(RenamableTitle, '1'), findsOneWidget);

    await widgetTester.enterText(
        find.widgetWithText(RenamableTitle, '0'), 'zone');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(path.constraintZones[0].name, 'zone');

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].name, '0');
  });

  testWidgets('Zone card hover', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          holonomicMode: true,
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
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          holonomicMode: true,
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

  testWidgets('Max vel text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'Max Velocity (M/S)');

    expect(textField, findsOneWidget);

    num oldVal = path.constraintZones[0].constraints.maxVelocity;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].constraints.maxVelocity, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].constraints.maxVelocity, oldVal);
  });

  testWidgets('Max accel text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Max Acceleration (M/S²)');

    expect(textField, findsOneWidget);

    num oldVal = path.constraintZones[0].constraints.maxAcceleration;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].constraints.maxAcceleration, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].constraints.maxAcceleration, oldVal);
  });

  testWidgets('Max ang vel text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Max Angular Velocity (Deg/S)');

    expect(textField, findsOneWidget);

    num oldVal = path.constraintZones[0].constraints.maxAngularVelocity;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].constraints.maxAngularVelocity, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].constraints.maxAngularVelocity, oldVal);
  });

  testWidgets('Max ang accel text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var textField = find.widgetWithText(
        NumberTextField, 'Max Angular Acceleration (Deg/S²)');

    expect(textField, findsOneWidget);

    num oldVal = path.constraintZones[0].constraints.maxAngularAcceleration;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].constraints.maxAngularAcceleration, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].constraints.maxAngularAcceleration, oldVal);
  });

  testWidgets('min pos slider', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var sliders = find.byType(Slider);

    expect(sliders, findsNWidgets(2));

    await widgetTester.tap(sliders.first); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].minWaypointRelativePos, 0.5);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.constraintZones[0].minWaypointRelativePos, 0.2);
  });

  testWidgets('max pos slider', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var sliders = find.byType(Slider);

    expect(sliders, findsNWidgets(2));

    await widgetTester.tap(sliders.last); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].maxWaypointRelativePos, 0.5);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.constraintZones[0].maxWaypointRelativePos, 0.7);
  });

  testWidgets('Delete zone button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var deleteButtons = find.byTooltip('Delete Zone');

    expect(deleteButtons, findsNWidgets(2));

    await widgetTester.tap(deleteButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones.length, 1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones.length, 2);
    expect(selectedZone, isNull);
  });

  testWidgets('move buttons hidden when zone selected', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          initiallySelectedZone: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var downButtons = find.byTooltip('Move Zone Down');
    var upButtons = find.byTooltip('Move Zone Up');

    expect(downButtons, findsNothing);
    expect(upButtons, findsNothing);
  });

  testWidgets('move zone down', (widgetTester) async {
    path.constraintZones.add(ConstraintsZone.defaultZone());
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    var downButtons = find.byTooltip('Move Zone Down');

    expect(downButtons, findsNWidgets(3));

    // Can't move last zone down
    await widgetTester.tap(downButtons.last);
    await widgetTester.pump();

    expect(pathChanged, false);

    var oldOrder = PathPlannerPath.cloneConstraintZones(path.constraintZones);

    await widgetTester.tap(downButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0], oldOrder[0]);
    expect(path.constraintZones[1], oldOrder[2]);
    expect(path.constraintZones[2], oldOrder[1]);
  });

  testWidgets('move zone up', (widgetTester) async {
    path.constraintZones.add(ConstraintsZone.defaultZone());
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    var upButtons = find.byTooltip('Move Zone Up');

    expect(upButtons, findsNWidgets(3));

    // Can't move first zone up
    await widgetTester.tap(upButtons.first);
    await widgetTester.pump();

    expect(pathChanged, false);

    var oldOrder = PathPlannerPath.cloneConstraintZones(path.constraintZones);

    await widgetTester.tap(upButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0], oldOrder[1]);
    expect(path.constraintZones[1], oldOrder[0]);
    expect(path.constraintZones[2], oldOrder[2]);
  });

  testWidgets('add new zone', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    var newZoneButton = find.text('Add New Zone');

    expect(newZoneButton, findsOneWidget);

    await widgetTester.tap(newZoneButton);
    await widgetTester.pump();

    expect(path.constraintZones.length, 3);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones.length, 2);
  });
}
