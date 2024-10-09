import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/info_card.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/add_command_button.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/event_markers_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

void main() {
  late ChangeStack undoStack;
  late PathPlannerPath path;
  late bool pathChanged;
  int? hoveredMarker;
  int? selectedMarker;

  setUp(() {
    undoStack = ChangeStack();
    path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.eventMarkersExpanded = true;
    path.eventMarkers = [
      EventMarker(
          command: SequentialCommandGroup(
            commands: [],
          ),
          waypointRelativePos: 0.2,
          endWaypointRelativePos: 0.8,
          name: '0'),
      EventMarker(name: '1'),
    ];
    pathChanged = false;
    hoveredMarker = null;
    selectedMarker = null;

    ProjectPage.events.add('0');
    ProjectPage.events.add('1');
  });

  testWidgets('name dropdown', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
        ),
      ),
    ));

    final dropdown = find.widgetWithText(DropdownButton2<String>, '0');

    expect(dropdown, findsOneWidget);

    await widgetTester.tap(dropdown);
    await widgetTester.pumpAndSettle();

    expect(find.text('0'), findsWidgets);
    expect(find.text('1'), findsWidgets);

    // flutter is dumb and won't actually select from a dropdown when you tap
    // it in a test so this test ends here i guess
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    path.eventMarkersExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
        ),
      ),
    ));

    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNothing);

    await widgetTester.tap(find.byType(EventMarkersTree));
    await widgetTester.pumpAndSettle();

    expect(path.eventMarkersExpanded, true);

    await widgetTester.tap(find.text('Event Markers'));
    await widgetTester.pumpAndSettle();
    expect(path.eventMarkersExpanded, false);
  });

  testWidgets('Marker card for each marker', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
        ),
      ),
    ));

    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNWidgets(2));
  });

  testWidgets('Marker card hover', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    var markerCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    await gesture.moveTo(widgetTester.getCenter(markerCards.at(0)));
    await widgetTester.pump();

    expect(hoveredMarker, 0);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredMarker, isNull);
  });

  testWidgets('tapping expands/collapses marker cards', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
        ),
      ),
    ));

    var markerCardTapSpots = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(InfoCard));

    expect(find.byType(Slider), findsNothing);

    await widgetTester.tap(markerCardTapSpots.at(0));
    await widgetTester.pumpAndSettle();
    expect(selectedMarker, 0);
    expect(find.byType(Slider), findsWidgets);

    await widgetTester.tap(markerCardTapSpots.at(1));
    await widgetTester.pump();
    expect(selectedMarker, 1);

    await widgetTester.tap(markerCardTapSpots.at(1));
    await widgetTester.pumpAndSettle();
    expect(selectedMarker, isNull);
  });

  testWidgets('position slider', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    var slider = find.byType(Slider);

    expect(slider, findsNWidgets(2));

    await widgetTester.tap(slider.first);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.eventMarkers[0].waypointRelativePos, closeTo(0.5, 0.01));

    undoStack.undo();
    await widgetTester.pump();

    expect(path.eventMarkers[0].waypointRelativePos, 0.2);
  });

  testWidgets('end position slider', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    var slider = find.byType(Slider);

    expect(slider, findsNWidgets(2));

    await widgetTester.tap(slider.last);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.eventMarkers[0].endWaypointRelativePos, closeTo(0.5, 0.01));

    undoStack.undo();
    await widgetTester.pump();

    expect(path.eventMarkers[0].endWaypointRelativePos, 0.8);
  });

  testWidgets('zoned checkbox', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    var zonedCheck = find.byType(Checkbox);

    expect(zonedCheck, findsOneWidget);

    await widgetTester.tap(zonedCheck);
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.eventMarkers[0].endWaypointRelativePos, isNull);

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.eventMarkers[0].endWaypointRelativePos, 0.8);

    await widgetTester.tap(zonedCheck);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(zonedCheck);
    await widgetTester.pumpAndSettle();

    expect(path.eventMarkers[0].endWaypointRelativePos,
        path.eventMarkers[0].waypointRelativePos);
  });

  testWidgets('add command button', (widgetTester) async {
    path.eventMarkers = [
      EventMarker(),
    ];

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    final button = find.byType(AddCommandButton);

    expect(button, findsOne);

    await widgetTester.tap(button);
    await widgetTester.pumpAndSettle();

    final named = find.text('Named Command');

    expect(named, findsOne);

    await widgetTester.tap(named);
    await widgetTester.pumpAndSettle();

    expect(path.eventMarkers.first.command, isNotNull);
    expect(path.eventMarkers.first.command, isInstanceOf<NamedCommand>());

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.eventMarkers.first.command, isNull);
  });

  testWidgets('change command group type', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    expect(find.byType(CommandGroupWidget), findsOneWidget);

    var typeDropdown = find.text('Sequential Group');

    expect(typeDropdown, findsOneWidget);

    await widgetTester.tap(typeDropdown);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Deadline Group').last);
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.eventMarkers[0].command, isInstanceOf<DeadlineCommandGroup>());

    undoStack.undo();
    await widgetTester.pump();

    expect(
        path.eventMarkers[0].command, isInstanceOf<SequentialCommandGroup>());
  });

  testWidgets('remove command', (widgetTester) async {
    path.eventMarkers = [
      EventMarker(
        command: NamedCommand(),
      ),
    ];

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    final removeButton = find.byTooltip('Remove Command');
    expect(removeButton, findsOneWidget);

    await widgetTester.tap(removeButton);
    await widgetTester.pumpAndSettle();

    expect(path.eventMarkers[0].command, isNull);

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(path.eventMarkers[0].command, isInstanceOf<NamedCommand>());
  });

  testWidgets('Delete marker button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    var deleteButtons = find.byIcon(Icons.delete_forever);

    expect(deleteButtons, findsNWidgets(2));

    await widgetTester.tap(deleteButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.eventMarkers.length, 1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.eventMarkers.length, 2);
    expect(selectedMarker, isNull);
  });

  testWidgets('add new marker', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    // Find the specific add button for event markers
    var newMarkerButton = find.descendant(
      of: find.byType(EventMarkersTree),
      matching: find.byIcon(Icons.add).first,
    );

    expect(newMarkerButton, findsOneWidget);

    await widgetTester.tap(newMarkerButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.eventMarkers.length, 3);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.eventMarkers.length, 2);
  });

  testWidgets('start pos text field', (widgetTester) async {
    path.eventMarkers = [
      EventMarker(
        command: SequentialCommandGroup(commands: []),
        waypointRelativePos: 0.25,
        endWaypointRelativePos: 0.75,
      ),
    ];

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'Start Pos');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '0.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.eventMarkers.first.waypointRelativePos, closeTo(0.1, 0.001));

    undoStack.undo();
    await widgetTester.pump();
    expect(path.eventMarkers.first.waypointRelativePos, closeTo(0.25, 0.001));
  });

  testWidgets('end pos text field', (widgetTester) async {
    path.eventMarkers = [
      EventMarker(
        command: SequentialCommandGroup(commands: []),
        waypointRelativePos: 0.25,
        endWaypointRelativePos: 0.75,
      ),
    ];

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EventMarkersTree(
          path: path,
          onPathChangedNoSim: () => pathChanged = true,
          onMarkerHovered: (value) => hoveredMarker = value,
          onMarkerSelected: (value) => selectedMarker = value,
          undoStack: undoStack,
          initiallySelectedMarker: 0,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'End Pos');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '0.9');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.eventMarkers.first.endWaypointRelativePos, closeTo(0.9, 0.001));

    undoStack.undo();
    await widgetTester.pump();
    expect(
        path.eventMarkers.first.endWaypointRelativePos, closeTo(0.75, 0.001));
  });
}
