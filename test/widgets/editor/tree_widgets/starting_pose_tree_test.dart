import 'dart:math';

import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/auto/starting_pose.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/starting_pose_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

void main() {
  testWidgets('starting pose tree', (widgetTester) async {
    PathPlannerAuto auto =
        PathPlannerAuto.defaultAuto(autoDir: '/autos', fs: MemoryFileSystem());

    bool autoChanged = false;
    var undoStack = ChangeStack();

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

    expect(find.byType(NumberTextField), findsNWidgets(3));
    expect(find.byType(Checkbox), findsOneWidget);
    expect(auto.startingPose, isNull);

    await widgetTester.tap(find.byType(Checkbox));
    await widgetTester.pumpAndSettle();

    expect(autoChanged, true);
    expect(auto.startingPose, isNotNull);
    autoChanged = false;

    auto.startingPose =
        StartingPose(position: const Point(1.0, 2.0), rotation: 3.0);
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StartingPoseTree(
          auto: auto,
          onAutoChanged: () => autoChanged = true,
          undoStack: undoStack,
        ),
      ),
    ));

    // X text field
    final xTextField = find.widgetWithText(NumberTextField, 'X Position (M)');
    expect(xTextField, findsOneWidget);
    expect(find.descendant(of: xTextField, matching: find.text('1.00')),
        findsOneWidget);
    await widgetTester.enterText(xTextField, '4.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(autoChanged, true);
    expect(auto.startingPose!.position.x, 4.0);
    undoStack.undo();
    await widgetTester.pump();
    expect(auto.startingPose!.position.x, 1.0);
    autoChanged = false;

    // Y text field
    final yTextField = find.widgetWithText(NumberTextField, 'Y Position (M)');
    expect(yTextField, findsOneWidget);
    expect(find.descendant(of: yTextField, matching: find.text('2.00')),
        findsOneWidget);
    await widgetTester.enterText(yTextField, '5.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(autoChanged, true);
    expect(auto.startingPose!.position.y, 5.0);
    undoStack.undo();
    await widgetTester.pump();
    expect(auto.startingPose!.position.y, 2.0);
    autoChanged = false;

    // Rotation text field
    final rotTextField = find.widgetWithText(NumberTextField, 'Rotation (Deg)');
    expect(rotTextField, findsOneWidget);
    expect(find.descendant(of: rotTextField, matching: find.text('3.00')),
        findsOneWidget);
    await widgetTester.enterText(rotTextField, '6.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(autoChanged, true);
    expect(auto.startingPose!.rotation, 6.0);
    undoStack.undo();
    await widgetTester.pump();
    expect(auto.startingPose!.rotation, 3.0);

    // Make sure rotation values wrap
    await widgetTester.enterText(rotTextField, '200.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(auto.startingPose!.rotation, -160.0);

    await widgetTester.enterText(rotTextField, '-200.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(auto.startingPose!.rotation, 160.0);

    // Tapping checkbox again removes starting pose
    autoChanged = false;
    await widgetTester.tap(find.byType(Checkbox));
    await widgetTester.pumpAndSettle();

    expect(autoChanged, true);
    expect(auto.startingPose, isNull);

    undoStack.undo();
    await widgetTester.pump();
    expect(auto.startingPose, isNotNull);
  });
}
