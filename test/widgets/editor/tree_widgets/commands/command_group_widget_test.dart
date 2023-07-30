import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/add_command_button.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/named_command_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/path_command_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/wait_command_widget.dart';
import 'package:undo/undo.dart';

void main() {
  late CommandGroup command;
  late ChangeStack undoStack;
  late bool updated;
  late bool removed;
  String? groupType;
  String? hoveredPathCommand;

  setUp(() {
    command = SequentialCommandGroup(commands: []);
    undoStack = ChangeStack();
    updated = false;
    removed = false;
    groupType = null;
    hoveredPathCommand = null;
  });

  testWidgets('change group type', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommandGroupWidget(
          command: command,
          undoStack: undoStack,
          onGroupTypeChanged: (value) => groupType = value,
          onPathCommandHovered: (value) => hoveredPathCommand = value,
          onRemoved: () => removed = true,
          onUpdated: () => updated = true,
          allPathNames: const ['path1', 'path2'],
        ),
      ),
    ));

    var typeDropdown = find.text('Sequential Group');

    expect(typeDropdown, findsOneWidget);

    await widgetTester.tap(typeDropdown);
    await widgetTester.pumpAndSettle();

    expect(find.text('Sequential Group'), findsWidgets);
    expect(find.text('Parallel Group'), findsOneWidget);
    expect(find.text('Race Group'), findsOneWidget);
    expect(find.text('Deadline Group'), findsOneWidget);

    await widgetTester.tap(find.text('Deadline Group'));
    await widgetTester.pumpAndSettle();

    expect(groupType, 'deadline');
  });

  testWidgets('add command to group', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommandGroupWidget(
          command: command,
          undoStack: undoStack,
          onGroupTypeChanged: (value) => groupType = value,
          onPathCommandHovered: (value) => hoveredPathCommand = value,
          onRemoved: () => removed = true,
          onUpdated: () => updated = true,
          allPathNames: const ['path1', 'path2'],
        ),
      ),
    ));

    var addButton = find.byType(AddCommandButton);

    expect(addButton, findsOneWidget);

    await widgetTester.tap(addButton);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Wait Command'));
    await widgetTester.pumpAndSettle();

    expect(updated, true);
    expect(command.commands.length, 1);

    undoStack.undo();
    await widgetTester.pump();

    expect(command.commands.length, 0);
  });

  testWidgets('remove button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommandGroupWidget(
          command: command,
          undoStack: undoStack,
          onGroupTypeChanged: (value) => groupType = value,
          onPathCommandHovered: (value) => hoveredPathCommand = value,
          onRemoved: () => removed = true,
          onUpdated: () => updated = true,
          allPathNames: const ['path1', 'path2'],
        ),
      ),
    ));

    var removeButton = find.byTooltip('Remove Command');

    expect(removeButton, findsOneWidget);

    await widgetTester.tap(removeButton);
    await widgetTester.pump();

    expect(removed, true);
  });

  testWidgets('shows sub commands', (widgetTester) async {
    command.commands = [
      WaitCommand(),
      NamedCommand(),
      PathCommand(),
      ParallelCommandGroup(commands: []),
    ];
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommandGroupWidget(
          command: command,
          undoStack: undoStack,
          onGroupTypeChanged: (value) => groupType = value,
          onPathCommandHovered: (value) => hoveredPathCommand = value,
          onRemoved: () => removed = true,
          onUpdated: () => updated = true,
          allPathNames: const ['path1', 'path2'],
        ),
      ),
    ));

    expect(find.byType(WaitCommandWidget), findsOneWidget);
    expect(find.byType(NamedCommandWidget), findsOneWidget);
    expect(find.byType(PathCommandWidget), findsOneWidget);
    expect(find.byType(CommandGroupWidget), findsNWidgets(2));
  });

  testWidgets('remove sub commands', (widgetTester) async {
    command.commands = [
      WaitCommand(),
      NamedCommand(),
      PathCommand(),
      ParallelCommandGroup(commands: []),
    ];
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommandGroupWidget(
          command: command,
          undoStack: undoStack,
          onGroupTypeChanged: (value) => groupType = value,
          onPathCommandHovered: (value) => hoveredPathCommand = value,
          removable: false,
          onUpdated: () => updated = true,
          allPathNames: const ['path1', 'path2'],
        ),
      ),
    ));

    await widgetTester.tap(find.byTooltip('Remove Command').first);
    await widgetTester.pump();

    expect(updated, true);
    expect(command.commands.length, 3);
    updated = false;

    await widgetTester.tap(find.byTooltip('Remove Command').first);
    await widgetTester.pump();

    expect(updated, true);
    expect(command.commands.length, 2);
    updated = false;

    await widgetTester.tap(find.byTooltip('Remove Command').first);
    await widgetTester.pump();

    expect(updated, true);
    expect(command.commands.length, 1);
    updated = false;

    await widgetTester.tap(find.byTooltip('Remove Command').first);
    await widgetTester.pump();

    expect(updated, true);
    expect(command.commands.length, 0);

    undoStack.undo();
    await widgetTester.pump();
    expect(command.commands.length, 1);

    undoStack.undo();
    await widgetTester.pump();
    expect(command.commands.length, 2);

    undoStack.undo();
    await widgetTester.pump();
    expect(command.commands.length, 3);

    undoStack.undo();
    await widgetTester.pump();
    expect(command.commands.length, 4);
  });

  testWidgets('change sub group type', (widgetTester) async {
    command.commands = [ParallelCommandGroup(commands: [])];
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommandGroupWidget(
          command: command,
          undoStack: undoStack,
          onGroupTypeChanged: (value) => groupType = value,
          onPathCommandHovered: (value) => hoveredPathCommand = value,
          onRemoved: () => removed = true,
          onUpdated: () => updated = true,
          allPathNames: const ['path1', 'path2'],
        ),
      ),
    ));

    var typeDropdown = find.text('Parallel Group');

    expect(typeDropdown, findsOneWidget);

    await widgetTester.tap(typeDropdown);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Deadline Group'));
    await widgetTester.pumpAndSettle();

    expect(updated, true);
    expect(command.commands[0].type, 'deadline');

    undoStack.undo();
    await widgetTester.pump();
    expect(command.commands[0].type, 'parallel');
  });

  testWidgets('path command hover', (widgetTester) async {
    command.commands = [PathCommand(pathName: 'path1')];
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommandGroupWidget(
          command: command,
          undoStack: undoStack,
          onGroupTypeChanged: (value) => groupType = value,
          onPathCommandHovered: (value) => hoveredPathCommand = value,
          onRemoved: () => removed = true,
          onUpdated: () => updated = true,
          allPathNames: const ['path1', 'path2'],
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture
        .moveTo(widgetTester.getCenter(find.byType(PathCommandWidget)));
    await widgetTester.pump();

    expect(hoveredPathCommand, 'path1');

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredPathCommand, isNull);
  });
}
