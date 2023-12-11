import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';

void main() {
  late bool opened;
  late bool duplicated;
  late bool deleted;
  String? name;

  setUp(() {
    opened = false;
    duplicated = false;
    deleted = false;
    name = null;
  });

  testWidgets('hover/open', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectItemCard(
          name: 'test',
          fieldImage: FieldImage.defaultField,
          paths: [
            PathPlannerPath.defaultPath(
              pathDir: '/paths',
              fs: MemoryFileSystem(),
            ).getPathPositions(),
          ],
          onOpened: () => opened = true,
          onDuplicated: () => duplicated = true,
          onDeleted: () => deleted = true,
          onRenamed: (value) => name = value,
          choreoItem: true,
        ),
      ),
    ));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(widgetTester.getCenter(find.byType(ProjectItemCard)));
    await widgetTester.pumpAndSettle();

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.byType(ProjectItemCard));
    await widgetTester.pump();

    expect(opened, true);
  });

  testWidgets('title', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectItemCard(
          name: 'test',
          fieldImage: FieldImage.defaultField,
          paths: [
            PathPlannerPath.defaultPath(
              pathDir: '/paths',
              fs: MemoryFileSystem(),
            ).getPathPositions(),
          ],
          onOpened: () => opened = true,
          onDuplicated: () => duplicated = true,
          onDeleted: () => deleted = true,
          onRenamed: (value) => name = value,
        ),
      ),
    ));

    final nameField = find.byType(RenamableTitle);

    expect(nameField, findsOneWidget);
    expect(find.descendant(of: nameField, matching: find.text('test')),
        findsOneWidget);

    await widgetTester.enterText(nameField, 'renamed');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(name, 'renamed');
  });

  testWidgets('duplicate', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectItemCard(
          name: 'test',
          fieldImage: FieldImage.defaultField,
          paths: [
            PathPlannerPath.defaultPath(
              pathDir: '/paths',
              fs: MemoryFileSystem(),
            ).getPathPositions(),
          ],
          onOpened: () => opened = true,
          onDuplicated: () => duplicated = true,
          onDeleted: () => deleted = true,
          onRenamed: (value) => name = value,
        ),
      ),
    ));

    final popup = find.byType(PopupMenuButton<String>);

    expect(popup, findsOneWidget);

    await widgetTester.tap(popup);
    await widgetTester.pumpAndSettle();

    expect(find.text('Duplicate'), findsOneWidget);

    await widgetTester.tap(find.text('Duplicate'));
    await widgetTester.pumpAndSettle();

    expect(duplicated, true);
  });

  testWidgets('delete cancel', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectItemCard(
          name: 'test',
          fieldImage: FieldImage.defaultField,
          paths: [
            PathPlannerPath.defaultPath(
              pathDir: '/paths',
              fs: MemoryFileSystem(),
            ).getPathPositions(),
          ],
          onOpened: () => opened = true,
          onDuplicated: () => duplicated = true,
          onDeleted: () => deleted = true,
          onRenamed: (value) => name = value,
        ),
      ),
    ));

    final popup = find.byType(PopupMenuButton<String>);

    expect(popup, findsOneWidget);

    await widgetTester.tap(popup);
    await widgetTester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await widgetTester.tap(find.text('Delete'));
    await widgetTester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);

    await widgetTester.tap(find.text('CANCEL'));
    await widgetTester.pumpAndSettle();

    expect(deleted, false);
  });

  testWidgets('delete confirm', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectItemCard(
          name: 'test',
          fieldImage: FieldImage.defaultField,
          paths: [
            PathPlannerPath.defaultPath(
              pathDir: '/paths',
              fs: MemoryFileSystem(),
            ).getPathPositions(),
          ],
          onOpened: () => opened = true,
          onDuplicated: () => duplicated = true,
          onDeleted: () => deleted = true,
          onRenamed: (value) => name = value,
        ),
      ),
    ));

    final popup = find.byType(PopupMenuButton<String>);

    expect(popup, findsOneWidget);

    await widgetTester.tap(popup);
    await widgetTester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await widgetTester.tap(find.text('Delete'));
    await widgetTester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('DELETE'), findsOneWidget);

    await widgetTester.tap(find.text('DELETE'));
    await widgetTester.pumpAndSettle();

    expect(deleted, true);
  });

  testWidgets('shows warning icon', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectItemCard(
          name: 'test',
          fieldImage: FieldImage.defaultField,
          paths: [
            PathPlannerPath.defaultPath(
              pathDir: '/paths',
              fs: MemoryFileSystem(),
            ).getPathPositions(),
          ],
          onOpened: () => opened = true,
          onDuplicated: () => duplicated = true,
          onDeleted: () => deleted = true,
          onRenamed: (value) => name = value,
          warningMessage: 'test warning',
        ),
      ),
    ));

    final warningIcon = find.byTooltip('test warning');

    expect(warningIcon, findsOneWidget);
  });
}
