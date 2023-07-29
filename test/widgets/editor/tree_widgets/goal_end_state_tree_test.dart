import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/goal_end_state_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

void main() {
  testWidgets('goal end state tree', (widgetTester) async {
    PathPlannerPath path =
        PathPlannerPath.defaultPath(pathDir: '/paths', fs: MemoryFileSystem());
    path.goalEndState = GoalEndState(
      velocity: 1.0,
      rotation: 2.0,
    );

    bool pathChanged = false;
    var undoStack = ChangeStack();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalEndStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(find.byType(GoalEndStateTree));
    await widgetTester.pumpAndSettle();

    expect(path.goalEndStateExpanded, true);
    expect(find.byType(NumberTextField), findsNWidgets(2));

    // Vel text field
    final velTextField = find.widgetWithText(NumberTextField, 'Velocity (M/S)');
    expect(velTextField, findsOneWidget);
    expect(find.descendant(of: velTextField, matching: find.text('1.00')),
        findsOneWidget);
    await widgetTester.enterText(velTextField, '3.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(pathChanged, true);
    expect(path.goalEndState.velocity, 3.0);
    undoStack.undo();
    await widgetTester.pump();
    expect(path.goalEndState.velocity, 1.0);
    pathChanged = false;

    // Rotation text field
    final rotTextField = find.widgetWithText(NumberTextField, 'Rotation (Deg)');
    expect(rotTextField, findsOneWidget);
    expect(find.descendant(of: rotTextField, matching: find.text('2.00')),
        findsOneWidget);
    await widgetTester.enterText(rotTextField, '4.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(pathChanged, true);
    expect(path.goalEndState.rotation, 4.0);
    undoStack.undo();
    await widgetTester.pump();
    expect(path.goalEndState.rotation, 2.0);
  });
}
