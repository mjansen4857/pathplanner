import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/reset_odom_tree.dart';
import 'package:undo/undo.dart';

void main() {
  testWidgets('reset odom check', (widgetTester) async {
    final auto = PathPlannerAuto(
      name: 'test',
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'testPath'),
        ],
      ),
      resetOdom: true,
      autoDir: '/autos',
      fs: MemoryFileSystem(),
      folder: null,
      choreoAuto: false,
    );
    ChangeStack undoStack = ChangeStack();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResetOdomTree(
          auto: auto,
          undoStack: undoStack,
        ),
      ),
    ));

    expect(find.text('Reset Odometry'), findsOneWidget);
    final checkbox = find.byType(Checkbox);
    expect(checkbox, findsOneWidget);

    await widgetTester.tap(checkbox);
    await widgetTester.pumpAndSettle();

    expect(auto.resetOdom, isFalse);

    undoStack.undo();
    await widgetTester.pumpAndSettle();

    expect(auto.resetOdom, isTrue);
  });
}
