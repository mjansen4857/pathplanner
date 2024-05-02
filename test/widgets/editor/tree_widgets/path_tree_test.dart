import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/constraint_zones_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/event_markers_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/global_constraints_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/goal_end_state_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/rotation_targets_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/waypoints_tree.dart';
import 'package:undo/undo.dart';

void main() {
  late PathPlannerPath path;
  bool sideSwapped = false;

  setUp(() {
    path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.reversed = false;
    sideSwapped = false;
  });

  testWidgets('has simulated driving time', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    expect(find.textContaining('Simulated Driving Time'), findsOneWidget);
  });

  testWidgets('swap side button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          onSideSwapped: () => sideSwapped = true,
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    var btn = find.byTooltip('Move to Other Side');

    expect(btn, findsOneWidget);

    await widgetTester.tap(btn);
    await widgetTester.pump();
    expect(sideSwapped, true);
  });

  testWidgets('has waypoints tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    expect(find.byType(WaypointsTree), findsOneWidget);
  });

  testWidgets('has constraint zones tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    expect(find.byType(ConstraintZonesTree), findsOneWidget);
  });

  testWidgets('has event markers tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    expect(find.byType(EventMarkersTree), findsOneWidget);
  });

  testWidgets('has global constraints tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    expect(find.byType(GlobalConstraintsTree), findsOneWidget);
  });

  testWidgets('has goal end state tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    expect(find.byType(GoalEndStateTree), findsOneWidget);
  });

  testWidgets('has rotation targets tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    expect(find.byType(RotationTargetsTree), findsOneWidget);
  });

  testWidgets('Reversed checkbox', (widgetTester) async {
    final ChangeStack undoStack = ChangeStack();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: undoStack,
          holonomicMode: false,
          defaultConstraints: PathConstraints(),
        ),
      ),
    ));

    final check = find.byType(Checkbox);

    expect(check, findsOneWidget);

    await widgetTester.tap(check);
    await widgetTester.pump();
    expect(path.reversed, true);

    undoStack.undo();

    await widgetTester.pump();
    expect(path.reversed, false);

    undoStack.redo();

    await widgetTester.pump();
    expect(path.reversed, true);
  });
}
