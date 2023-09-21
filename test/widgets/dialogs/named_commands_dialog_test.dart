import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/widgets/dialogs/named_commands_dialog.dart';

void main() {
  tearDown(() {
    Command.named.clear();
  });

  testWidgets('shows named commands', (widgetTester) async {
    Command.named.add('test1');
    Command.named.add('test2');

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NamedCommandsDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {},
        ),
      ),
    ));

    expect(find.text('test1'), findsOneWidget);
    expect(find.text('test2'), findsOneWidget);
  });

  testWidgets('remove command', (widgetTester) async {
    Command.named.add('test1');

    bool removed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NamedCommandsDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {
            removed = true;
          },
        ),
      ),
    ));

    final cmdTile = find.widgetWithText(ListTile, 'test1');

    expect(cmdTile, findsOneWidget);

    final removeBtn = find.descendant(
        of: cmdTile, matching: find.byTooltip('Remove named command'));

    expect(removeBtn, findsOneWidget);

    await widgetTester.tap(removeBtn);
    await widgetTester.pumpAndSettle();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(removed, true);
    expect(Command.named.contains('test1'), false);
  });

  testWidgets('rename command', (widgetTester) async {
    Command.named.add('test1');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NamedCommandsDialog(
          onCommandRenamed: (p0, p1) {
            renamed = true;
          },
          onCommandDeleted: (p0) {},
        ),
      ),
    ));

    final cmdTile = find.widgetWithText(ListTile, 'test1');

    expect(cmdTile, findsOneWidget);

    final renameBtn = find.descendant(
        of: cmdTile, matching: find.byTooltip('Rename named command'));

    expect(renameBtn, findsOneWidget);

    await widgetTester.tap(renameBtn);
    await widgetTester.pumpAndSettle();

    final textField = find.byType(TextField);

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, 'test1renamed');
    await widgetTester.pump();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(renamed, true);
    expect(Command.named.contains('test1'), false);
    expect(Command.named.contains('test1renamed'), true);
  });

  testWidgets('rename command invalid', (widgetTester) async {
    Command.named.add('test1');
    Command.named.add('test2');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NamedCommandsDialog(
          onCommandRenamed: (p0, p1) {
            renamed = true;
          },
          onCommandDeleted: (p0) {},
        ),
      ),
    ));

    final cmdTile = find.widgetWithText(ListTile, 'test1');

    expect(cmdTile, findsOneWidget);

    final renameBtn = find.descendant(
        of: cmdTile, matching: find.byTooltip('Rename named command'));

    expect(renameBtn, findsOneWidget);

    await widgetTester.tap(renameBtn);
    await widgetTester.pumpAndSettle();

    final textField = find.byType(TextField);

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, 'test2');
    await widgetTester.pump();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(renamed, false);
    expect(Command.named.contains('test1'), true);
  });

  testWidgets('rename command no change', (widgetTester) async {
    Command.named.add('test1');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NamedCommandsDialog(
          onCommandRenamed: (p0, p1) {
            renamed = true;
          },
          onCommandDeleted: (p0) {},
        ),
      ),
    ));

    final cmdTile = find.widgetWithText(ListTile, 'test1');

    expect(cmdTile, findsOneWidget);

    final renameBtn = find.descendant(
        of: cmdTile, matching: find.byTooltip('Rename named command'));

    expect(renameBtn, findsOneWidget);

    await widgetTester.tap(renameBtn);
    await widgetTester.pumpAndSettle();

    final textField = find.byType(TextField);

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, 'test1');
    await widgetTester.pump();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(renamed, false);
    expect(Command.named.contains('test1'), true);
  });
}
