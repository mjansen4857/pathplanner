import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/path_command_widget.dart';
import 'package:undo/undo.dart';

void main() {
  late PathCommand cmd;
  late ChangeStack undoStack;
  late bool removed;
  // late bool updated;

  setUp(() {
    cmd = PathCommand();
    undoStack = ChangeStack();
    removed = false;
    // updated = false;
  });

  testWidgets('path dropdown', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathCommandWidget(
          command: cmd,
          undoStack: undoStack,
          allPathNames: const ['path1', 'path2'],
          onRemoved: () => removed = true,
          // onUpdated: () => updated = true,
        ),
      ),
    ));

    final dropdown = find.byType(DropdownMenu<String>);

    expect(dropdown, findsOneWidget);

    await widgetTester.tap(dropdown);
    await widgetTester.pumpAndSettle();

    expect(find.text('path1'), findsWidgets);
    expect(find.text('path2'), findsWidgets);

    // flutter is dumb and won't actually select from a dropdown when you tap
    // it in a test so this test ends here i guess
  });

  testWidgets('remove button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathCommandWidget(
          command: cmd,
          allPathNames: const [],
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
