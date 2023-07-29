import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/waypoints_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

void main() {
  testWidgets('Waypoints tree', (widgetTester) async {
    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );

    var undoStack = ChangeStack();

    bool pathChanged = false;
    int? waypointDeleted;
    int? hoveredWaypoint;
    int? selectedWaypoint;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => waypointDeleted = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(find.byType(WaypointsTree));
    await widgetTester.pumpAndSettle();

    expect(path.waypointsExpanded, true);

    var startPoint = find.text('Start Point');
    var midPoint = find.text('Waypoint 1');
    var endPoint = find.text('End Point');

    expect(startPoint, findsOneWidget);
    expect(midPoint, findsOneWidget);
    expect(endPoint, findsOneWidget);

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(widgetTester.getCenter(midPoint));
    await widgetTester.pump();

    expect(hoveredWaypoint, 1);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredWaypoint, isNull);

    await widgetTester.tap(midPoint);
    await widgetTester.pumpAndSettle();

    expect(selectedWaypoint, 1);

    var iconButtons = find.descendant(
        of: find.ancestor(of: midPoint, matching: find.byType(Row)),
        matching: find.byType(IconButton));
    var xPosField = find.widgetWithText(NumberTextField, 'X Position (M)');
    var yPosField = find.widgetWithText(NumberTextField, 'Y Position (M)');
    var headingField = find.widgetWithText(NumberTextField, 'Heading (Deg)');
    var prevLengthField =
        find.widgetWithText(NumberTextField, 'Previous Control Length (M)');
    var nextLengthField =
        find.widgetWithText(NumberTextField, 'Next Control Length (M)');
    var insertButton = find.text('Insert New Waypoint After');

    expect(iconButtons, findsNWidgets(2));
    expect(xPosField, findsOneWidget);
    expect(yPosField, findsOneWidget);
    expect(headingField, findsOneWidget);
    expect(prevLengthField, findsOneWidget);
    expect(nextLengthField, findsOneWidget);
    expect(insertButton, findsOneWidget);

    List<Waypoint> oldWaypoints =
        PathPlannerPath.cloneWaypoints(path.waypoints);

    // Test x pos field
    pathChanged = false;
    await widgetTester.enterText(xPosField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].anchor.x, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].anchor.x, oldWaypoints[1].anchor.x);

    // Test y pos field
    pathChanged = false;
    await widgetTester.enterText(yPosField, '0.2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].anchor.y, 0.2);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].anchor.y, oldWaypoints[1].anchor.y);

    // Test heading field
    pathChanged = false;
    await widgetTester.enterText(headingField, '0.3');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].getHeadingDegrees(), closeTo(0.3, 0.01));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].getHeadingDegrees(),
        closeTo(oldWaypoints[1].getHeadingDegrees(), 0.01));

    // Test prev length field
    pathChanged = false;
    await widgetTester.enterText(prevLengthField, '0.4');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].getPrevControlLength(), closeTo(0.4, 0.01));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].getPrevControlLength(),
        closeTo(oldWaypoints[1].getPrevControlLength(), 0.01));

    // Test next length field
    pathChanged = false;
    await widgetTester.enterText(nextLengthField, '0.5');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].getNextControlLength(), closeTo(0.5, 0.01));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].getNextControlLength(),
        closeTo(oldWaypoints[1].getNextControlLength(), 0.01));

    // test insert button
    pathChanged = false;
    await widgetTester.tap(insertButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints.length, 4);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.waypoints.length, oldWaypoints.length);
    expect(selectedWaypoint, isNull);

    // test lock button
    pathChanged = false;
    await widgetTester.tap(iconButtons.first);
    await widgetTester.pump();

    expect(pathChanged, true);

    // test delete button
    waypointDeleted = null;
    await widgetTester.tap(iconButtons.last);
    await widgetTester.pump();

    expect(waypointDeleted, 1);
  });

  testWidgets('various expansion tests', (widgetTester) async {
    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );

    var undoStack = ChangeStack();
    var controller = WaypointsTreeController();
    int? selectedWaypoint;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onWaypointSelected: (value) => selectedWaypoint = value,
          controller: controller,
        ),
      ),
    ));

    await widgetTester.tap(find.byType(WaypointsTree));
    await widgetTester.pumpAndSettle();

    expect(path.waypointsExpanded, true);

    await widgetTester.tap(find.text('Waypoints'));
    await widgetTester.pumpAndSettle();
    expect(path.waypointsExpanded, false);

    await widgetTester.tap(find.byType(WaypointsTree));
    await widgetTester.pumpAndSettle();

    expect(find.byType(NumberTextField), findsNothing);
    controller.setSelectedWaypoint(0);
    await widgetTester.pumpAndSettle();
    expect(find.widgetWithText(NumberTextField, 'Next Control Length (M)'),
        findsOneWidget);
    expect(find.widgetWithText(NumberTextField, 'Previous Control Length (M)'),
        findsNothing);

    controller.setSelectedWaypoint(2);
    await widgetTester.pumpAndSettle();
    expect(find.widgetWithText(NumberTextField, 'Previous Control Length (M)'),
        findsOneWidget);
    expect(find.widgetWithText(NumberTextField, 'Next Control Length (M)'),
        findsNothing);

    var midPoint = find.text('Waypoint 1');
    await widgetTester.tap(midPoint);
    await widgetTester.pumpAndSettle();
    expect(selectedWaypoint, 1);

    await widgetTester.tap(midPoint);
    await widgetTester.pumpAndSettle();
    expect(selectedWaypoint, isNull);
  });
}
