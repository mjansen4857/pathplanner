import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/dialogs/management_dialog.dart';

import '../../test_helpers.dart';

void main() {
  tearDown(() {
    Command.named.clear();
  });

  testWidgets('shows named commands', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Command.named.add('test1');
    Command.named.add('test2');

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    expect(find.text('test1'), findsOneWidget);
    expect(find.text('test2'), findsOneWidget);
  });

  testWidgets('shows linked waypoints', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Point(0, 0);
    Waypoint.linked['link2'] = const Point(0, 0);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    await widgetTester.tap(find.text('Manage Linked Waypoints'));
    await widgetTester.pumpAndSettle();

    expect(find.text('link1'), findsOneWidget);
    expect(find.text('link2'), findsOneWidget);
  });

  testWidgets('remove command', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Command.named.add('test1');

    bool removed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {
            removed = true;
          },
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
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

  testWidgets('remove linked', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Point(0, 0);

    bool removed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {
            removed = true;
          },
        ),
      ),
    ));

    await widgetTester.tap(find.text('Manage Linked Waypoints'));
    await widgetTester.pumpAndSettle();

    final linkTile = find.widgetWithText(ListTile, 'link1');

    expect(linkTile, findsOneWidget);

    final removeBtn = find.descendant(
        of: linkTile, matching: find.byTooltip('Remove linked waypoint'));

    expect(removeBtn, findsOneWidget);

    await widgetTester.tap(removeBtn);
    await widgetTester.pumpAndSettle();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(removed, true);
  });

  testWidgets('rename command', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Command.named.add('test1');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {
            renamed = true;
          },
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
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

  testWidgets('rename linked', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Point(0, 0);

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {
            renamed = true;
          },
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    await widgetTester.tap(find.text('Manage Linked Waypoints'));
    await widgetTester.pumpAndSettle();

    final linkTile = find.widgetWithText(ListTile, 'link1');

    expect(linkTile, findsOneWidget);

    final renameBtn = find.descendant(
        of: linkTile, matching: find.byTooltip('Rename linked waypoint'));

    expect(renameBtn, findsOneWidget);

    await widgetTester.tap(renameBtn);
    await widgetTester.pumpAndSettle();

    final textField = find.byType(TextField);

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, 'link1renamed');
    await widgetTester.pump();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(renamed, true);
  });

  testWidgets('rename command invalid', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Command.named.add('test1');
    Command.named.add('test2');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {
            renamed = true;
          },
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
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

  testWidgets('rename linked invalid', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Point(0, 0);
    Waypoint.linked['link2'] = const Point(0, 0);

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {
            renamed = true;
          },
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    await widgetTester.tap(find.text('Manage Linked Waypoints'));
    await widgetTester.pumpAndSettle();

    final linkTile = find.widgetWithText(ListTile, 'link1');

    expect(linkTile, findsOneWidget);

    final renameBtn = find.descendant(
        of: linkTile, matching: find.byTooltip('Rename linked waypoint'));

    expect(renameBtn, findsOneWidget);

    await widgetTester.tap(renameBtn);
    await widgetTester.pumpAndSettle();

    final textField = find.byType(TextField);

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, 'link2');
    await widgetTester.pump();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(renamed, false);
  });

  testWidgets('rename command no change', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Command.named.add('test1');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {
            renamed = true;
          },
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
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

  testWidgets('rename linked no change', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Point(0, 0);

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onCommandRenamed: (p0, p1) {},
          onCommandDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {
            renamed = true;
          },
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    await widgetTester.tap(find.text('Manage Linked Waypoints'));
    await widgetTester.pumpAndSettle();

    final linkTile = find.widgetWithText(ListTile, 'link1');

    expect(linkTile, findsOneWidget);

    final renameBtn = find.descendant(
        of: linkTile, matching: find.byTooltip('Rename linked waypoint'));

    expect(renameBtn, findsOneWidget);

    await widgetTester.tap(renameBtn);
    await widgetTester.pumpAndSettle();

    final textField = find.byType(TextField);

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, 'link1');
    await widgetTester.pump();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(renamed, false);
  });
}
