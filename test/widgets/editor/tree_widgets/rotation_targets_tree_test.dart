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
  late ChangeStack undoStack;
  late PathPlannerPath path;
  late bool pathChanged;
  int? hoveredTarget;
  int? selectedTarget;

  setUp(() {
    undoStack = ChangeStack();
    path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.rotationTargets = [
      RotationTarget(
        waypointRelativePos: 0.2,
        rotationDegrees: 0.0,
        rotateFast: false,
      ),
      RotationTarget(
        waypointRelativePos: 0.7,
        rotationDegrees: 0.0,
        rotateFast: false,
      ),
    ];
    path.rotationTargetsExpanded = true;
    pathChanged = false;
    hoveredTarget = null;
    selectedTarget = null;
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    path.rotationTargetsExpanded = false;
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
    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNothing);

    await widgetTester.tap(find.byType(RotationTargetsTree));
    await widgetTester.pumpAndSettle();

    expect(path.rotationTargetsExpanded, true);

    await widgetTester.tap(find.text(
        'Rotation Targets')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(path.rotationTargetsExpanded, false);
  });

  testWidgets('Target card for each zone', (widgetTester) async {
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

    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNWidgets(2));
  });

  testWidgets('Target card titles', (widgetTester) async {
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

    expect(find.text('Rotation Target at 0.20'), findsOneWidget);
    expect(find.text('Rotation Target at 0.70'), findsOneWidget);
  });

  testWidgets('Target card hover', (widgetTester) async {
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

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    var targetCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    await gesture.moveTo(widgetTester.getCenter(targetCards.at(0)));
    await widgetTester.pump();

    expect(hoveredTarget, 0);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredTarget, isNull);
  });

  testWidgets('tapping expands/collapses zone cards', (widgetTester) async {
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

    var targetCards = find.descendant(
        of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode));

    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(targetCards.at(0));
    await widgetTester.pumpAndSettle();
    expect(selectedTarget, 0);
    expect(find.byType(NumberTextField), findsWidgets);

    await widgetTester.tap(targetCards.at(1));
    await widgetTester.pump();
    expect(selectedTarget, 1);

    await widgetTester.tap(targetCards.at(1));
    await widgetTester.pumpAndSettle();
    expect(selectedTarget, isNull);
  });

  testWidgets('Rotation text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RotationTargetsTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onTargetHovered: (value) => hoveredTarget = value,
          onTargetSelected: (value) => selectedTarget = value,
          undoStack: undoStack,
          initiallySelectedTarget: 0,
        ),
      ),
    ));

    var textField = find.widgetWithText(NumberTextField, 'Rotation (Deg)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '200.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets[0].rotationDegrees, -160.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.rotationTargets[0].rotationDegrees, 0.0);
  });

  testWidgets('pos slider', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RotationTargetsTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onTargetHovered: (value) => hoveredTarget = value,
          onTargetSelected: (value) => selectedTarget = value,
          undoStack: undoStack,
          initiallySelectedTarget: 0,
        ),
      ),
    ));

    var slider = find.byType(Slider);

    expect(slider, findsOneWidget);

    await widgetTester.tap(slider.first); // will tap the center
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets[0].waypointRelativePos, 0.5);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.rotationTargets[0].waypointRelativePos, 0.2);
  });

  testWidgets('Delete target button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RotationTargetsTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onTargetHovered: (value) => hoveredTarget = value,
          onTargetSelected: (value) => selectedTarget = value,
          undoStack: undoStack,
          initiallySelectedTarget: 0,
        ),
      ),
    ));

    var deleteButtons = find.byTooltip('Delete Target');

    expect(deleteButtons, findsNWidgets(2));

    await widgetTester.tap(deleteButtons.at(1));
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets.length, 1);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.rotationTargets.length, 2);
    expect(selectedTarget, isNull);
  });

  testWidgets('add new target', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RotationTargetsTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onTargetHovered: (value) => hoveredTarget = value,
          onTargetSelected: (value) => selectedTarget = value,
          undoStack: undoStack,
          initiallySelectedTarget: 0,
        ),
      ),
    ));

    var newTargetButton = find.text('Add New Rotation Target');

    expect(newTargetButton, findsOneWidget);

    await widgetTester.tap(newTargetButton);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets.length, 3);

    undoStack.undo();
    await widgetTester.pump();
    expect(path.rotationTargets.length, 2);
  });

  testWidgets('rotate fast', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RotationTargetsTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onTargetHovered: (value) => hoveredTarget = value,
          onTargetSelected: (value) => selectedTarget = value,
          undoStack: undoStack,
          initiallySelectedTarget: 0,
        ),
      ),
    ));

    var checkbox = find.byType(Checkbox);

    expect(checkbox, findsOneWidget);

    await widgetTester.tap(checkbox);
    await widgetTester.pump();

    expect(pathChanged, true);
    expect(path.rotationTargets[0].rotateFast, true);

    undoStack.undo();
    await widgetTester.pump();

    expect(path.rotationTargets[0].rotateFast, false);
  });
}
