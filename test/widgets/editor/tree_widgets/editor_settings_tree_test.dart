import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/editor_settings_tree.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.snapToGuidelines: false,
      PrefsKeys.hidePathsOnHover: false,
    });
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('snap to guidelines check', (widgetTester) async {
    await widgetTester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EditorSettingsTree(
          initiallyExpanded: true,
        ),
      ),
    ));
    await widgetTester.pump();

    final snapRow = find.widgetWithText(Row, 'Snap To Guidelines');

    expect(snapRow, findsOneWidget);

    final snapCheck =
        find.descendant(of: snapRow, matching: find.byType(Checkbox));

    expect(snapCheck, findsOneWidget);

    await widgetTester.tap(snapCheck);
    await widgetTester.pumpAndSettle();

    expect(prefs.getBool(PrefsKeys.snapToGuidelines), true);

    await widgetTester.tap(snapCheck);
    await widgetTester.pumpAndSettle();

    expect(prefs.getBool(PrefsKeys.snapToGuidelines), false);
  });

  testWidgets('hide paths check', (widgetTester) async {
    await widgetTester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EditorSettingsTree(
          initiallyExpanded: true,
        ),
      ),
    ));
    await widgetTester.pump();

    final row = find.widgetWithText(Row, 'Hide Other Paths on Hover');

    expect(row, findsOneWidget);

    final check = find.descendant(of: row, matching: find.byType(Checkbox));

    expect(check, findsOneWidget);

    await widgetTester.tap(check);
    await widgetTester.pumpAndSettle();

    expect(prefs.getBool(PrefsKeys.hidePathsOnHover), true);

    await widgetTester.tap(check);
    await widgetTester.pumpAndSettle();

    expect(prefs.getBool(PrefsKeys.hidePathsOnHover), false);
  });
}
