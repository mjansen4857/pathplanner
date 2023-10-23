import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/preview_starting_state.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/preview_starting_state_tree.dart';
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
    path.previewStartingState =
        PreviewStartingState(velocity: 1.0, rotation: 45);
    path.previewStartingStateExpanded = true;
    pathChanged = false;
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    path.previewStartingStateExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PreviewStartingStateTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          undoStack: undoStack,
          holonomicMode: true,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(find.byType(PreviewStartingStateTree));
    await widgetTester.pumpAndSettle();

    expect(find.byType(NumberTextField), findsWidgets);

    await widgetTester.tap(find.text(
        'Preview Starting State')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(find.byType(NumberTextField), findsNothing);
  });

  testWidgets('velocity text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PreviewStartingStateTree(
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
    expect(path.previewStartingState!.velocity, 3.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.previewStartingState!.velocity, 1.0);
  });

  testWidgets('rotation text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PreviewStartingStateTree(
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
    expect(path.previewStartingState!.rotation, -90.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.previewStartingState!.rotation, 45.0);
  });

  testWidgets('checkbox adds state', (widgetTester) async {
    path.previewStartingState = null;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PreviewStartingStateTree(
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
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.previewStartingState, isNotNull);

    undoStack.undo();
    expect(path.previewStartingState, isNull);
  });

  testWidgets('checkbox removes state', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PreviewStartingStateTree(
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
    await widgetTester.pumpAndSettle();

    expect(pathChanged, true);
    expect(path.previewStartingState, isNull);

    undoStack.undo();
    expect(path.previewStartingState, isNotNull);
  });
}
