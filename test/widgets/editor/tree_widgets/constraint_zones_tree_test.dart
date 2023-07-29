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
  testWidgets('constraint zones tree', (widgetTester) async {
    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.constraintZones = [
      ConstraintsZone(
        constraints: PathConstraints(),
        minWaypointRelativePos: 0.2,
        maxWaypointRelativePos: 1.8,
        name: '0',
      ),
      ConstraintsZone(
        constraints: PathConstraints(),
        minWaypointRelativePos: 1.2,
        maxWaypointRelativePos: 1.8,
        name: '1',
      ),
    ];
    var undoStack = ChangeStack();

    bool pathChanged = false;
    int? hoveredZone;
    int? selectedZone;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(RenamableTitle), findsNothing);

    await widgetTester.tap(find.byType(ConstraintZonesTree));
    await widgetTester.pumpAndSettle();

    expect(path.constraintZonesExpanded, true);

    var zoneTrees = find.ancestor(
        of: find.byType(RenamableTitle),
        matching: find.descendant(
            of: find.byType(TreeCardNode),
            matching: find.byType(TreeCardNode)));
    expect(zoneTrees, findsNWidgets(2));

    pathChanged = false;
    await widgetTester.enterText(
        find.descendant(
            of: zoneTrees.first, matching: find.byType(RenamableTitle)),
        'zone');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(pathChanged, true);
    expect(path.constraintZones[0].name, 'zone');

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].name, '0');

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(widgetTester.getCenter(zoneTrees.first));
    await widgetTester.pump();

    expect(hoveredZone, 0);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredZone, isNull);

    await widgetTester.tap(zoneTrees.first);
    await widgetTester.pumpAndSettle();

    expect(selectedZone, 0);

    var maxVelField =
        find.widgetWithText(NumberTextField, 'Max Velocity (M/S)');
    var maxAccelField =
        find.widgetWithText(NumberTextField, 'Max Acceleration (M/S²)');
    var maxAngVelField =
        find.widgetWithText(NumberTextField, 'Max Angular Velocity (Deg/S)');
    var maxAngAccelField = find.widgetWithText(
        NumberTextField, 'Max Angular Acceleration (Deg/S²)');
    var sliders = find.byType(Slider);
    var newZoneButton = find.text('Add New Zone');

    expect(maxVelField, findsOneWidget);
    expect(maxAccelField, findsOneWidget);
    expect(maxAngVelField, findsOneWidget);
    expect(maxAngAccelField, findsOneWidget);
    expect(sliders, findsNWidgets(2));
    expect(newZoneButton, findsOneWidget);

    // Test max vel text field
    pathChanged = false;
    await widgetTester.enterText(maxVelField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].constraints.maxVelocity, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].constraints.maxVelocity,
        path.constraintZones[1].constraints.maxVelocity);

    // Test max accel text field
    pathChanged = false;
    await widgetTester.enterText(maxAccelField, '0.2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].constraints.maxAcceleration, 0.2);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].constraints.maxAcceleration,
        path.constraintZones[1].constraints.maxAcceleration);

    // Test max ang vel text field
    pathChanged = false;
    await widgetTester.enterText(maxAngVelField, '0.3');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].constraints.maxAngularVelocity, 0.3);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].constraints.maxAngularVelocity,
        path.constraintZones[1].constraints.maxAngularVelocity);

    // Test max ang accel text field
    pathChanged = false;
    await widgetTester.enterText(maxAngAccelField, '0.4');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].constraints.maxAngularAcceleration, 0.4);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones[0].constraints.maxAngularAcceleration,
        path.constraintZones[1].constraints.maxAngularAcceleration);

    // test min slider
    pathChanged = false;
    await widgetTester.tap(sliders.first); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].minWaypointRelativePos, 1.0);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.constraintZones[0].minWaypointRelativePos, 0.2);

    // test max slider
    pathChanged = false;
    await widgetTester.tap(sliders.last); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].maxWaypointRelativePos, 1.0);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.constraintZones[0].maxWaypointRelativePos, 1.8);

    // test delete button
    pathChanged = false;
    var iconButtons =
        find.descendant(of: zoneTrees.first, matching: find.byType(IconButton));
    expect(iconButtons, findsNWidgets(3)); // Includes order buttons
    var deleteButton = iconButtons.at(2);

    await widgetTester.tap(deleteButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(selectedZone, isNull);
    expect(path.constraintZones.length, 1);

    undoStack.undo();

    await widgetTester.pump();
    expect(path.constraintZones.length, 2);
    expect(selectedZone, isNull);

    // test move down button
    pathChanged = false;
    var downButton = iconButtons.at(1);
    await widgetTester.tap(downButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].minWaypointRelativePos, 1.2);
    expect(path.constraintZones[1].minWaypointRelativePos, 0.2);

    // test move up button
    pathChanged = false;
    iconButtons =
        find.descendant(of: zoneTrees.last, matching: find.byType(IconButton));
    var upButton = iconButtons.at(0);
    await widgetTester.tap(upButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones[0].minWaypointRelativePos, 0.2);
    expect(path.constraintZones[1].minWaypointRelativePos, 1.2);

    // test add new zone button
    pathChanged = false;
    await widgetTester.tap(newZoneButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.constraintZones.length, 3);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.constraintZones.length, 2);
  });

  testWidgets('various expansion tests', (widgetTester) async {
    // For some reason this needs to be done in a seperate test
    // or it wont work. Flutter dumb
    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.constraintZones = [
      ConstraintsZone(
        constraints: PathConstraints(),
        minWaypointRelativePos: 0.2,
        maxWaypointRelativePos: 1.8,
        name: '0',
      ),
      ConstraintsZone(
        constraints: PathConstraints(),
        minWaypointRelativePos: 1.2,
        maxWaypointRelativePos: 1.8,
        name: '1',
      ),
    ];
    var undoStack = ChangeStack();
    int? selectedZone;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    await widgetTester.tap(find.byType(ConstraintZonesTree));
    await widgetTester.pumpAndSettle();

    expect(path.constraintZonesExpanded, true);

    await widgetTester.tap(find.text('Constraint Zones'));
    await widgetTester.pumpAndSettle();
    expect(path.constraintZonesExpanded, false);

    await widgetTester.tap(find.byType(ConstraintZonesTree));
    await widgetTester.pumpAndSettle();

    var zoneTrees = find.ancestor(
        of: find.byType(RenamableTitle),
        matching: find.descendant(
            of: find.byType(TreeCardNode),
            matching: find.byType(TreeCardNode)));
    expect(zoneTrees, findsNWidgets(2));
    expect(selectedZone, isNull);
    await widgetTester.tap(zoneTrees.first);
    await widgetTester.pumpAndSettle();
    expect(selectedZone, 0);

    await widgetTester.tap(zoneTrees.last);
    // Don't settle here so that card doesn't fully expand, allowing
    // us to easily tap it again to close it
    await widgetTester.pump();
    expect(selectedZone, 1);

    await widgetTester.tap(zoneTrees.last);
    await widgetTester.pumpAndSettle();
    expect(selectedZone, isNull);
  });
}
