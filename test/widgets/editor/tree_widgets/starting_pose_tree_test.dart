import 'dart:math';

import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/starting_pose_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

void main() {
  late ChangeStack undoStack;
  late PathPlannerAuto auto;
  late bool autoChanged;

  setUp(() {
    undoStack = ChangeStack();
    auto = PathPlannerAuto.defaultAuto(
      autoDir: '/paths',
      fs: MemoryFileSystem(),
    );
    auto.startingPose = Pose2d(position: const Point(0, 0), rotation: 0);
    autoChanged = false;
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StartingPoseTree(
          auto: auto,
          onAutoChanged: () => autoChanged = true,
          undoStack: undoStack,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(find.byType(StartingPoseTree));
    await widgetTester.pumpAndSettle();

    expect(find.byType(NumberTextField), findsWidgets);

    await widgetTester.tap(find.text(
        'Starting Pose')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(find.byType(NumberTextField), findsNothing);
  });

  testWidgets('x position text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StartingPoseTree(
          auto: auto,
          onAutoChanged: () => autoChanged = true,
          undoStack: undoStack,
          initiallyExpanded: true,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'X Position (M)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '1.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(autoChanged, true);
    expect(auto.startingPose!.position.x, 1.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(auto.startingPose!.position.x, 0.0);
  });

  testWidgets('y position text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StartingPoseTree(
          auto: auto,
          onAutoChanged: () => autoChanged = true,
          undoStack: undoStack,
          initiallyExpanded: true,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Y Position (M)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '1.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(autoChanged, true);
    expect(auto.startingPose!.position.y, 1.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(auto.startingPose!.position.y, 0.0);
  });

  testWidgets('rotation text field', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StartingPoseTree(
          auto: auto,
          onAutoChanged: () => autoChanged = true,
          undoStack: undoStack,
          initiallyExpanded: true,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Rotation (Deg)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '200.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(autoChanged, true);
    expect(auto.startingPose!.rotation, -160.0);

    undoStack.undo();
    await widgetTester.pump();
    expect(auto.startingPose!.rotation, 0.0);
  });

  testWidgets('checkbox adds pose', (widgetTester) async {
    auto.startingPose = null;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StartingPoseTree(
          auto: auto,
          onAutoChanged: () => autoChanged = true,
          undoStack: undoStack,
          initiallyExpanded: true,
        ),
      ),
    ));

    final checkbox = find.byType(Checkbox);

    expect(checkbox, findsOneWidget);

    await widgetTester.tap(checkbox);
    await widgetTester.pumpAndSettle();

    expect(autoChanged, true);
    expect(auto.startingPose, isNotNull);

    undoStack.undo();
    expect(auto.startingPose, isNull);
  });

  testWidgets('checkbox removes pose', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StartingPoseTree(
          auto: auto,
          onAutoChanged: () => autoChanged = true,
          undoStack: undoStack,
          initiallyExpanded: true,
        ),
      ),
    ));

    final checkbox = find.byType(Checkbox);

    expect(checkbox, findsOneWidget);

    await widgetTester.tap(checkbox);
    await widgetTester.pumpAndSettle();

    expect(autoChanged, true);
    expect(auto.startingPose, isNull);

    undoStack.undo();
    expect(auto.startingPose, isNotNull);
  });
}
