import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
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
          holonomicMode: true,
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
          holonomicMode: true,
        ),
      ),
    ));

    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNWidgets(2));
  });

  testWidgets('waypoint card titles', (widgetTester) async {
    path.addWaypoint(const Translation2d(7.0, 4.0));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          holonomicMode: true,
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
          holonomicMode: true,
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
          holonomicMode: true,
        ),
      ),
    ));

    var waypointCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(waypointCards.at(0));
    await widgetTester.pumpAndSettle();
    expect(selectedWaypoint, 0);
    expect(find.byType(NumberTextField), findsWidgets);

    await widgetTester.tap(waypointCards.at(1));
    await widgetTester.pumpAndSettle();
    expect(selectedWaypoint, 1);

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
          holonomicMode: true,
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
          holonomicMode: true,
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
          holonomicMode: true,
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
          holonomicMode: true,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Heading (Deg)');

    expect(textField, findsOneWidget);

    final oldVal = path.waypoints[1].heading;

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].heading.degrees, closeTo(0.1, epsilon));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].heading.degrees, closeTo(oldVal.degrees, epsilon));
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
          holonomicMode: true,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Previous Control Length (M)');

    expect(textField, findsOneWidget);

    num oldVal = path.waypoints[1].prevControlLength!;

    await widgetTester.enterText(textField, '0.75');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[1].prevControlLength, closeTo(0.75, epsilon));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[1].prevControlLength, closeTo(oldVal, epsilon));
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
          initialSelectedWaypoint: 0,
          holonomicMode: true,
        ),
      ),
    ));

    var textField =
        find.widgetWithText(NumberTextField, 'Next Control Length (M)');

    expect(textField, findsOneWidget);

    num oldVal = path.waypoints[0].nextControlLength!;

    await widgetTester.enterText(textField, '0.75');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints[0].nextControlLength, closeTo(0.75, epsilon));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.waypoints[0].nextControlLength, closeTo(oldVal, epsilon));
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
          initialSelectedWaypoint: 0,
          holonomicMode: true,
        ),
      ),
    ));

    // Expand the waypoint card first
    await widgetTester.tap(find.byType(TreeCardNode).first);
    await widgetTester.pumpAndSettle();

    var insertButton = find.byIcon(Icons.add);

    expect(insertButton, findsOneWidget);

    await widgetTester.tap(insertButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.waypoints.length, 3);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.waypoints.length, 2);
    expect(selectedWaypoint, isNull);
  });

  testWidgets('Add rotation target button', (widgetTester) async {
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
          holonomicMode: true,
        ),
      ),
    ));

    // Expand the waypoint card first
    await widgetTester.tap(find.byType(TreeCardNode).at(1));
    await widgetTester.pumpAndSettle();

    var button = find.byIcon(Icons.rotate_right_rounded);

    expect(button, findsOneWidget);

    await widgetTester.tap(button);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets.length, 1);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.rotationTargets.length, 0);
  });

  testWidgets('linked waypoint', (widgetTester) async {
    Waypoint.linked['existing link'] = const Translation2d(0, 0);
    Waypoint.linked['new link'] = const Translation2d(0, 0);

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
          holonomicMode: true,
        ),
      ),
    ));

    // Find the link icon button
    var linkButton = find.byIcon(Icons.add_link_rounded);

    expect(linkButton, findsOneWidget);

    await widgetTester.tap(linkButton);
    await widgetTester.pumpAndSettle();

    final cancelButton = find.text('Cancel');

    expect(cancelButton, findsOneWidget);
    await widgetTester.tap(cancelButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);

    await widgetTester.tap(linkButton);
    await widgetTester.pumpAndSettle();

    final dropdown =
        find.widgetWithText(DropdownMenu<String>, 'Linked Waypoint Name');
    expect(dropdown, findsOneWidget);

    await widgetTester.tap(dropdown);
    await widgetTester.pumpAndSettle();

    Waypoint.linked.remove('new link');

    // Stupid that there are duplicate text widgets. The dropdown menu is the worst widget in flutter
    await widgetTester.tap(find.text('new link').last);
    await widgetTester.pumpAndSettle();

    final confirmButton = find.text('Confirm');
    expect(confirmButton, findsOneWidget);

    await widgetTester.tap(confirmButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);

    expect(pathChanged, true);
    expect(path.waypoints[1].linkedName, 'new link');

    final unlinkButton = find.byIcon(Icons.link_off);
    await widgetTester.tap(unlinkButton);
    await widgetTester.pumpAndSettle();

    expect(path.waypoints[1].linkedName, null);

    await widgetTester.tap(linkButton);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(dropdown);
    await widgetTester.pumpAndSettle();

    // Stupid that there are duplicate text widgets. The dropdown menu is the worst widget in flutter
    await widgetTester.tap(find.text('existing link').last);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(confirmButton);
    await widgetTester.pumpAndSettle();

    expect(path.waypoints[1].linkedName, 'existing link');
    expect(path.waypoints[1].anchor.x, closeTo(0.0, 0.01));
    expect(path.waypoints[1].anchor.y, closeTo(0.0, 0.01));

    // Undo existing
    undoStack.undo();
    await widgetTester.pump();

    // Undo unlink
    undoStack.undo();
    await widgetTester.pump();

    // Undo new link
    undoStack.undo();
    await widgetTester.pump();

    expect(path.waypoints[1].linkedName, null);
  });

  testWidgets('Lock waypoint button', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          holonomicMode: true,
        ),
      ),
    ));

    final Finder lockButton = find.byType(IconButton).first;

    await tester.ensureVisible(lockButton);
    await tester.pumpAndSettle();

    await tester.tap(lockButton);
    await tester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.waypoints[0].isLocked, true);

    await tester.tap(lockButton);
    await tester.pumpAndSettle();

    expect(path.waypoints[0].isLocked, false);
  });

  testWidgets('Delete waypoint button', (widgetTester) async {
    path.addWaypoint(const Translation2d(7.0, 4.0));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaypointsTree(
          path: path,
          undoStack: undoStack,
          onPathChanged: () => pathChanged = true,
          onWaypointDeleted: (value) => deletedWaypoint = value,
          onWaypointHovered: (value) => hoveredWaypoint = value,
          onWaypointSelected: (value) => selectedWaypoint = value,
          holonomicMode: true,
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
          holonomicMode: true,
        ),
      ),
    ));

    var delButtons = find.byTooltip('Delete Waypoint');

    expect(delButtons, findsNothing);
  });
}
