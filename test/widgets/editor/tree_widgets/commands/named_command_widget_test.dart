import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/named_command_widget.dart';
import 'package:undo/undo.dart';

void main() {
  late NamedCommand cmd;
  late ChangeStack undoStack;
  late bool removed;
  // late bool updated;

  Command.named.addAll(['test1', 'test2']);

  setUp(() {
    cmd = NamedCommand();
    undoStack = ChangeStack();
    removed = false;
    // updated = false;
  });

  testWidgets('name dropdown', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NamedCommandWidget(
          command: cmd,
          undoStack: undoStack,
          onRemoved: () => removed = true,
          // onUpdated: () => updated = true,
        ),
      ),
    ));

    final dropdown = find.byType(DropdownMenu<String>);

    expect(dropdown, findsOneWidget);

    await widgetTester.tap(dropdown);
    await widgetTester.pumpAndSettle();

    expect(find.text('test1'), findsWidgets);
    expect(find.text('test2'), findsWidgets);

    // flutter is dumb and won't actually select from a dropdown when you tap
    // it in a test so this test ends here i guess
  });

  testWidgets('remove button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NamedCommandWidget(
          command: cmd,
          undoStack: undoStack,
          onRemoved: () => removed = true,
          // onUpdated: () => updated = true,
        ),
      ),
    ));

    final removeButton = find.byTooltip('Remove Command');

    expect(removeButton, findsOneWidget);

    await widgetTester.tap(removeButton);
    await widgetTester.pump();

    expect(removed, true);
  });
}
