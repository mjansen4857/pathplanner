import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/ideal_starting_state_tree.dart';
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
    path.idealStartingState = IdealStartingState(1.0, Rotation2d.fromDegrees(45));
    path.previewStartingStateExpanded = true;
    pathChanged = false;
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    path.previewStartingStateExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IdealStartingStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(find.byType(IdealStartingStateTree));
    await widgetTester.pumpAndSettle();

    expect(find.byType(NumberTextField), findsWidgets);

    await widgetTester.tap(
        find.text('Preview Starting State')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(find.byType(NumberTextField), findsNothing);
  });

  testWidgets('velocity text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IdealStartingStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Velocity (M/S)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '3.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.idealStartingState.velocityMPS, 3.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.idealStartingState.velocityMPS, 1.0);
  });

  testWidgets('rotation text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IdealStartingStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Rotation (Deg)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '-90.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.idealStartingState.rotation.degrees, -90.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.idealStartingState.rotation.degrees, 45.0);
  });
}
