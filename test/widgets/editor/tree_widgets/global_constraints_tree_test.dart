import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/global_constraints_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';

void main() {
  testWidgets('global constraints tree', (widgetTester) async {
    PathPlannerPath path = PathPlannerPath.defaultPath();
    path.globalConstraints = PathConstraints(
      maxVelocity: 1.0,
      maxAcceleration: 2.0,
      maxAngularVelocity: 3.0,
      maxAngularAcceleration: 4.0,
    );

    bool pathChanged = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlobalConstraintsTree(
          path: path,
          onPathChanged: () => pathChanged = true,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(NumberTextField), findsNothing);

    await widgetTester.tap(find.byType(GlobalConstraintsTree));
    await widgetTester.pumpAndSettle();

    expect(path.globalConstraintsExpanded, true);
    expect(find.byType(NumberTextField), findsNWidgets(4));

    // Max vel text field
    final maxVelTextField =
        find.widgetWithText(NumberTextField, 'Max Velocity (M/S)');
    expect(maxVelTextField, findsOneWidget);
    expect(find.descendant(of: maxVelTextField, matching: find.text('1.00')),
        findsOneWidget);
    await widgetTester.enterText(maxVelTextField, '5.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(pathChanged, true);
    expect(path.globalConstraints.maxVelocity, 5.0);
    pathChanged = false;

    // Max accel text field
    final maxAccelTextField =
        find.widgetWithText(NumberTextField, 'Max Acceleration (M/S²)');
    expect(maxAccelTextField, findsOneWidget);
    expect(find.descendant(of: maxAccelTextField, matching: find.text('2.00')),
        findsOneWidget);
    await widgetTester.enterText(maxAccelTextField, '6.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(pathChanged, true);
    expect(path.globalConstraints.maxAcceleration, 6.0);
    pathChanged = false;

    // Max angular vel text field
    final maxAngVelTextField =
        find.widgetWithText(NumberTextField, 'Max Angular Velocity (Deg/S)');
    expect(maxAngVelTextField, findsOneWidget);
    expect(find.descendant(of: maxAngVelTextField, matching: find.text('3.00')),
        findsOneWidget);
    await widgetTester.enterText(maxAngVelTextField, '7.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(pathChanged, true);
    expect(path.globalConstraints.maxAngularVelocity, 7.0);
    pathChanged = false;

    // Max angular accel text field
    final maxAngAccelTextField = find.widgetWithText(
        NumberTextField, 'Max Angular Acceleration (Deg/S²)');
    expect(maxAngAccelTextField, findsOneWidget);
    expect(
        find.descendant(of: maxAngAccelTextField, matching: find.text('4.00')),
        findsOneWidget);
    await widgetTester.enterText(maxAngAccelTextField, '8.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(pathChanged, true);
    expect(path.globalConstraints.maxAngularAcceleration, 8.0);
  });
}
