import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/waypoints_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

const num epsilon = 0.001;

void main() {
  late ChangeStack undoStack;
  late PathPlannerPath path;
  late bool pathChanged;
  int? deletedWaypoint;
  int? hoveredWaypoint;
  int? selectedWaypoint;

  setUp(() {
    undoStack = ChangeStack();
    path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.waypointsExpanded = true;
    pathChanged = false;
    deletedWaypoint = null;
    hoveredWaypoint = null;
    selectedWaypoint = null;
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    path.waypointsExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNothing);

    await widgetTester.tap(find.byType(WaypointsTree));
    await widgetTester.pumpAndSettle();
    expect(path.waypointsExpanded, true);

    await widgetTester.tap(find.text(
        'Waypoints')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(path.waypointsExpanded, false);
  });

  testWidgets('waypoint card for each waypoint', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNWidgets(3));
  });

  testWidgets('waypoint card titles', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    expect(find.text('Start Point'), findsOneWidget);
    expect(find.text('Waypoint 1'), findsOneWidget);
    expect(find.text('End Point'), findsOneWidget);
  });

  testWidgets('waypoint card hover', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    var waypointCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    await gesture.moveTo(widgetTester.getCenter(waypointCards.at(1)));
    await widgetTester.pump();

    expect(hoveredWaypoint, 1);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredWaypoint, isNull);
  });

  testWidgets('tapping expands/collapses waypoint cards', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    var waypointCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(waypointCards.at(1));
    await widgetTester.pumpAndSettle();
    expect(selectedWaypoint, 1);
    expect(find.byType(NumberTextField), findsWidgets);

    await widgetTester.tap(waypointCards.at(2));
    await widgetTester.pumpAndSettle();
    expect(selectedWaypoint, 2);

    await widgetTester.tap(find.text('End Point'));
    await widgetTester.pumpAndSettle();
    expect(selectedWaypoint, isNull);
  });

  testWidgets('Controller expands/collapses waypoint cards',
      (widgetTester) async {
    var controller = WaypointsTreeController();
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          controller: controller,
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    expect(find.byType(NumberTextField), findsNothing);

    controller.setSelectedWaypoint(1);
    await widgetTester.pumpAndSettle();
    expect(find.byType(NumberTextField), findsWidgets);

    controller.setSelectedWaypoint(1);
    await widgetTester.pumpAndSettle();
    expect(find.byType(NumberTextField), findsWidgets);

    controller.setSelectedWaypoint(null);
    await widgetTester.pumpAndSettle();
    expect(find.byType(NumberTextField), findsNothing);
  });

  testWidgets('X Position text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          initialSelectedWaypoint: 1,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'X Position (M)');

    expect(textField, findsOneWidget);

    num oldVal = path.waypoints[1].anchor.x;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].anchor.x, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].anchor.x, oldVal);
  });

  testWidgets('Y Position text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          initialSelectedWaypoint: 1,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'Y Position (M)');

    expect(textField, findsOneWidget);

    num oldVal = path.waypoints[1].anchor.y;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].anchor.y, 0.1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].anchor.y, oldVal);
  });

  testWidgets('Heading text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          initialSelectedWaypoint: 1,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'Heading (Deg)');

    expect(textField, findsOneWidget);

    num oldVal = path.waypoints[1].getHeadingDegrees();

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].getHeadingDegrees(), closeTo(0.1, epsilon));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].getHeadingDegrees(), closeTo(oldVal, epsilon));
  });

  testWidgets('Prev length text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          initialSelectedWaypoint: 1,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Previous Control Length (M)');

    expect(textField, findsOneWidget);

    num oldVal = path.waypoints[1].getPrevControlLength();

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].getPrevControlLength(), closeTo(0.1, epsilon));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].getPrevControlLength(), closeTo(oldVal, epsilon));
  });

  testWidgets('Next length text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          initialSelectedWaypoint: 1,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Next Control Length (M)');

    expect(textField, findsOneWidget);

    num oldVal = path.waypoints[1].getNextControlLength();

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].getNextControlLength(), closeTo(0.1, epsilon));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].getNextControlLength(), closeTo(oldVal, epsilon));
  });

  testWidgets('Insert waypoint button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          initialSelectedWaypoint: 1,
        ),
      ),
    ));

    var insertButton = find.text('Insert New Waypoint After');

    expect(insertButton, findsOneWidget);

    await widgetTester.tap(insertButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints.length, 4);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.waypoints.length, 3);
    expect(selectedWaypoint, isNull);
  });

  testWidgets('Lock waypoint button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    var lockButtons = find.byTooltip('Lock');

    expect(lockButtons, findsNWidgets(3));

    await widgetTester.tap(lockButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].isLocked, true);

    await widgetTester.tap(lockButtons.at(1));
    await widgetTester.pump();

    expect(path.waypoints[1].isLocked, false);
  });

  testWidgets('Delete waypoint button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    var delButtons = find.byTooltip('Delete Waypoint');

    expect(delButtons, findsNWidgets(3));

    await widgetTester.tap(delButtons.at(1));
    await widgetTester.pump();

    expect(deletedWaypoint, 1);
  });

  testWidgets('Delete waypoint button hidden w/ 2 waypoints',
      (widgetTester) async {
    path.waypoints.removeAt(1);
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
        ),
      ),
    ));

    var delButtons = find.byTooltip('Delete Waypoint');

    expect(delButtons, findsNothing);
  });
}
