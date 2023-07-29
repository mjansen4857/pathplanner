import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/rotation_targets_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

void main() {
  testWidgets('constraint zones tree', (widgetTester) async {
    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.rotationTargets = [
      RotationTarget(
        waypointRelativePos: 0.2,
        rotationDegrees: 0.0,
      ),
      RotationTarget(
        waypointRelativePos: 1.2,
        rotationDegrees: 90.0,
      ),
    ];
    var undoStack = ChangeStack();

    bool pathChanged = false;
    int? hoveredTarget;
    int? selectedTarget;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RotationTargetsTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onTargetHovered: (value) => hoveredTarget = value,
          onTargetSelected: (value) => selectedTarget = value,
          undoStack: undoStack,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.textContaining('Rotation Target at'), findsNothing);

    await widgetTester.tap(find.byType(RotationTargetsTree));
    await widgetTester.pumpAndSettle();

    expect(path.rotationTargetsExpanded, true);

    var targetTrees = find.ancestor(
        of: find.textContaining('Rotation Target at'),
        matching: find.descendant(
            of: find.byType(TreeCardNode),
            matching: find.byType(TreeCardNode)));
    expect(targetTrees, findsNWidgets(2));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(widgetTester.getCenter(targetTrees.first));
    await widgetTester.pump();

    expect(hoveredTarget, 0);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredTarget, isNull);

    await widgetTester.tap(targetTrees.first);
    await widgetTester.pumpAndSettle();

    expect(selectedTarget, 0);

    var rotationField = find.widgetWithText(NumberTextField, 'Rotation (Deg)');
    var slider = find.byType(Slider);
    var newTargetButton = find.text('Add New Rotation Target');

    expect(rotationField, findsOneWidget);
    expect(slider, findsOneWidget);
    expect(newTargetButton, findsOneWidget);

    // Test rotation text field
    pathChanged = false;
    await widgetTester.enterText(rotationField, '200.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets[0].rotationDegrees, -160.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.rotationTargets[0].rotationDegrees, 0.0);

    // test slider
    pathChanged = false;
    await widgetTester.tap(slider); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets[0].waypointRelativePos, 1.0);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.rotationTargets[0].waypointRelativePos, 0.2);

    // test delete button
    pathChanged = false;
    var deleteButton = find.descendant(
        of: targetTrees.first, matching: find.byType(IconButton));
    expect(deleteButton, findsOneWidget);

    await widgetTester.tap(deleteButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(selectedTarget, isNull);
    expect(path.rotationTargets.length, 1);

    undoStack.undo();

    await widgetTester.pump();
    expect(path.rotationTargets.length, 2);
    expect(selectedTarget, isNull);

    // test add new target button
    pathChanged = false;
    await widgetTester.tap(newTargetButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets.length, 3);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.rotationTargets.length, 2);
  });

  testWidgets('various expansion tests', (widgetTester) async {
    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.rotationTargets = [
      RotationTarget(
        waypointRelativePos: 0.2,
        rotationDegrees: 0.0,
      ),
      RotationTarget(
        waypointRelativePos: 1.2,
        rotationDegrees: 90.0,
      ),
    ];
    var undoStack = ChangeStack();
    int? selectedTarget;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RotationTargetsTree(
          path: path,
          onTargetSelected: (value) => selectedTarget = value,
          undoStack: undoStack,
        ),
      ),
    ));

    await widgetTester.tap(find.byType(RotationTargetsTree));
    await widgetTester.pumpAndSettle();

    expect(path.rotationTargetsExpanded, true);

    await widgetTester.tap(find.text('Rotation Targets'));
    await widgetTester.pumpAndSettle();
    expect(path.rotationTargetsExpanded, false);

    await widgetTester.tap(find.byType(RotationTargetsTree));
    await widgetTester.pumpAndSettle();

    var targetTrees = find.ancestor(
        of: find.textContaining('Rotation Target at'),
        matching: find.descendant(
            of: find.byType(TreeCardNode),
            matching: find.byType(TreeCardNode)));
    expect(targetTrees, findsNWidgets(2));
    expect(selectedTarget, isNull);
    await widgetTester.tap(targetTrees.first);
    await widgetTester.pumpAndSettle();
    expect(selectedTarget, 0);

    await widgetTester.tap(targetTrees.last);
    // Don't settle here so that card doesn't fully expand, allowing
    // us to easily tap it again to close it
    await widgetTester.pump();
    expect(selectedTarget, 1);

    await widgetTester.tap(targetTrees.last);
    await widgetTester.pumpAndSettle();
    expect(selectedTarget, isNull);
  });
}
