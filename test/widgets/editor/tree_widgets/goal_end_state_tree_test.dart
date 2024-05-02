import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/goal_end_state_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

void main() {
  late ChangeStack undoStack;
  late PathPlannerPath path;
  late bool pathChanged;

  setUp(() {
    undoStack = ChangeStack();
    path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.goalEndStateExpanded = true;
    path.goalEndState = GoalEndState(
      velocity: 1.0,
      rotation: 1.0,
      rotateFast: false,
    );
    pathChanged = false;
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    path.goalEndStateExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalEndStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(find.byType(GoalEndStateTree));
    await widgetTester.pumpAndSettle();

    expect(path.goalEndStateExpanded, true);

    await widgetTester.tap(find.text(
        'Goal End State')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(path.goalEndStateExpanded, false);
  });

  testWidgets('vel text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalEndStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Velocity (M/S)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '2.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.goalEndState.velocity, 2.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.goalEndState.velocity, 1.0);
  });

  testWidgets('rotation text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalEndStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Rotation (Deg)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '200.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.goalEndState.rotation, -160.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.goalEndState.rotation, 1.0);
  });

  testWidgets('rotate fast', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalEndStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    final checkbox = find.byType(Checkbox);

    expect(checkbox, findsOneWidget);

    await widgetTester.tap(checkbox);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.goalEndState.rotateFast, true);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.goalEndState.rotateFast, false);
  });
}
