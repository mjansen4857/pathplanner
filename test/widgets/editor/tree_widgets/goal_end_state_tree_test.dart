import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
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
    path.goalEndState = GoalEndState(1.0, const Rotation2d(1.0));
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

    // Find and tap the GoalEndStateTree widget
    await widgetTester.tap(find.byType(GoalEndStateTree));
    await widgetTester.pumpAndSettle();

    expect(path.goalEndStateExpanded, true);
    expect(find.byType(NumberTextField), findsWidgets);

    // Tap the title to collapse
    await widgetTester.tap(find.text('Goal End State'));
    await widgetTester.pumpAndSettle();

    expect(path.goalEndStateExpanded, false);
    expect(find.byType(NumberTextField), findsNothing);
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
    expect(path.goalEndState.velocityMPS, 2.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.goalEndState.velocityMPS, 1.0);
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
    expect(path.goalEndState.rotation.degrees, -160.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.goalEndState.rotation.radians, 1.0);
  });
}
