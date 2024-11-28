import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/dialogs/management_dialog.dart';

import '../../test_helpers.dart';

void main() {
  tearDown(() {
    ProjectPage.events.clear();
  });

  testWidgets('shows events', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    ProjectPage.events.add('test1');
    ProjectPage.events.add('test2');

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {},
          onEventDeleted: (p0) {},
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

    Waypoint.linked['link1'] = const Translation2d(0, 0);
    Waypoint.linked['link2'] = const Translation2d(0, 0);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {},
          onEventDeleted: (p0) {},
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

  testWidgets('remove event', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    ProjectPage.events.add('test1');

    bool removed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {},
          onEventDeleted: (p0) {
            removed = true;
          },
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    final cmdTile = find.widgetWithText(ListTile, 'test1');

    expect(cmdTile, findsOneWidget);

    final removeBtn =
        find.descendant(of: cmdTile, matching: find.byTooltip('Remove event'));

    expect(removeBtn, findsOneWidget);

    await widgetTester.tap(removeBtn);
    await widgetTester.pumpAndSettle();

    final confirmBtn = find.text('Confirm');

    expect(confirmBtn, findsOneWidget);

    await widgetTester.tap(confirmBtn);
    await widgetTester.pumpAndSettle();

    expect(removed, true);
    expect(ProjectPage.events.contains('test1'), false);
  });

  testWidgets('remove linked', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Translation2d(0, 0);

    bool removed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {},
          onEventDeleted: (p0) {},
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

  testWidgets('rename event', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    ProjectPage.events.add('test1');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {
            renamed = true;
          },
          onEventDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    final cmdTile = find.widgetWithText(ListTile, 'test1');

    expect(cmdTile, findsOneWidget);

    final renameBtn =
        find.descendant(of: cmdTile, matching: find.byTooltip('Rename event'));

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
    expect(ProjectPage.events.contains('test1'), false);
    expect(ProjectPage.events.contains('test1renamed'), true);
  });

  testWidgets('rename linked', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Translation2d(0, 0);

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {},
          onEventDeleted: (p0) {},
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

  testWidgets('rename event invalid', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    ProjectPage.events.add('test1');
    ProjectPage.events.add('test2');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {
            renamed = true;
          },
          onEventDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    final cmdTile = find.widgetWithText(ListTile, 'test1');

    expect(cmdTile, findsOneWidget);

    final renameBtn =
        find.descendant(of: cmdTile, matching: find.byTooltip('Rename event'));

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
    expect(ProjectPage.events.contains('test1'), true);
  });

  testWidgets('rename linked invalid', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Translation2d(0, 0);
    Waypoint.linked['link2'] = const Translation2d(0, 0);

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {},
          onEventDeleted: (p0) {},
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

  testWidgets('rename event no change', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    ProjectPage.events.add('test1');

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {
            renamed = true;
          },
          onEventDeleted: (p0) {},
          onLinkedRenamed: (p0, p1) {},
          onLinkedDeleted: (p0) {},
        ),
      ),
    ));

    final cmdTile = find.widgetWithText(ListTile, 'test1');

    expect(cmdTile, findsOneWidget);

    final renameBtn =
        find.descendant(of: cmdTile, matching: find.byTooltip('Rename event'));

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
    expect(ProjectPage.events.contains('test1'), true);
  });

  testWidgets('rename linked no change', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    Waypoint.linked['link1'] = const Translation2d(0, 0);

    bool renamed = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManagementDialog(
          onEventRenamed: (p0, p1) {},
          onEventDeleted: (p0) {},
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
