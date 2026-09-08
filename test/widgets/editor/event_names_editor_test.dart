import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/services/project_event_registry.dart';
import 'package:pathplanner/widgets/editor/event_names_editor.dart';

void main() {
  setUp(ProjectEventRegistry.clear);

  testWidgets(
    'anchored picker filters registered names and selects in one click',
    (tester) async {
      final semantics = tester.ensureSemantics();
      ProjectEventRegistry.events.addAll(['Score', 'Intake', 'Inspect']);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EventAddButton(onSelected: (name) => selected = name),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add event'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.widgetWithText(MenuItemButton, 'Score'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'INT');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, 'Score'), findsNothing);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Intake'));
      await tester.pumpAndSettle();
      expect(selected, 'Intake');
      expect(find.byType(TextField), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('creation trims names, rejects blank input, and Escape cancels', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EventAddButton(onSelected: (name) => selected = name),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.enterText(find.byType(TextField), '  Acquire  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create “Acquire”'));
    await tester.pumpAndSettle();
    expect(selected, 'Acquire');
    selected = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(ProjectEventRegistry.events, isEmpty);
  });

  testWidgets('keyboard selection and exact duplicate chip deletion work', (
    tester,
  ) async {
    ProjectEventRegistry.events.add('Intake');
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EventAddButton(onSelected: (name) => selected = name),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'int');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(selected, 'Intake');
    int? removed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 296,
            child: WaypointEventsSection(
              names: const ['Intake', 'Intake'],
              onAdd: (_) {},
              onRemove: (index) => removed = index,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    expect(removed, 1);
  });
  testWidgets(
    'event chips use primary tint and an icon-only red failure indicator',
    (tester) async {
      const colors = ColorScheme.light(
        primary: Colors.indigo,
        error: Colors.red,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colors),
          home: Scaffold(
            body: Center(
              child: EventChip(
                name: 'Intake',
                status: 'Unreached: Traversal 1',
                onRemove: () {},
              ),
            ),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(EventChip),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Color.lerp(colors.surface, colors.primary, 0.12));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded)).color,
        colors.error,
      );
      expect(find.text('Unreached'), findsNothing);
      expect(find.byTooltip('Unreached: Traversal 1'), findsOneWidget);
    },
  );
}
