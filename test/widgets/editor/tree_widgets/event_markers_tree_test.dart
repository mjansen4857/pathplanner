import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/event_markers_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
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
          name: '0'),
      EventMarker.defaultMarker()..name = '1',
    ];
    pathChanged = false;
    hoveredMarker = null;
    selectedMarker = null;
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

    // Tree initially collapsed, expect to find nothing
    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNothing);

    await widgetTester.tap(find.byType(EventMarkersTree));
    await widgetTester.pumpAndSettle();

    expect(path.eventMarkersExpanded, true);

    await widgetTester.tap(find.text(
        'Event Markers')); // Use text so it doesn't tap middle of expanded card
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

  testWidgets('Marker card titles', (widgetTester) async {
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

    expect(find.widgetWithText(RenamableTitle, '0'), findsOneWidget);
    expect(find.widgetWithText(RenamableTitle, '1'), findsOneWidget);

    await widgetTester.enterText(
        find.widgetWithText(RenamableTitle, '0'), 'marker');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.eventMarkers[0].name, 'marker');

    undoStack.undo();
    await widgetTester.pump();
    expect(path.eventMarkers[0].name, '0');
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

    var markerCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    expect(find.byType(Slider), findsNothing);

    await widgetTester.tap(markerCards.at(0));
    await widgetTester.pumpAndSettle();
    expect(selectedMarker, 0);
    expect(find.byType(Slider), findsWidgets);

    await widgetTester.tap(markerCards.at(1));
    await widgetTester.pump();
    expect(selectedMarker, 1);

    await widgetTester.tap(markerCards.at(1));
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

    expect(slider, findsOneWidget);

    await widgetTester.tap(slider); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.eventMarkers[0].waypointRelativePos, 0.5);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.eventMarkers[0].waypointRelativePos, 0.2);
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

    await widgetTester.tap(find.text('Deadline Group'));
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.eventMarkers[0].command.type, 'deadline');

    undoStack.undo();
    await widgetTester.pump();

    expect(path.eventMarkers[0].command.type, 'sequential');
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

    var deleteButtons = find.byTooltip('Delete Marker');

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

    var newMarkerButton = find.text('Add New Marker');

    expect(newMarkerButton, findsOneWidget);

    await widgetTester.tap(newMarkerButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.eventMarkers.length, 3);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.eventMarkers.length, 2);
  });
}
