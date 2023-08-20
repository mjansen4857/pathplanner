import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/editor_settings_tree.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.displaySimPath: false,
      PrefsKeys.snapToGuidelines: false,
    });
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('display sim path check', (widgetTester) async {
    await widgetTester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EditorSettingsTree(
          initiallyExpanded: true,
        ),
      ),
    ));
    await widgetTester.pump();

    final simPathRow = find.widgetWithText(Row, 'Display Simulated Path');

    expect(simPathRow, findsOneWidget);

    final simPathCheck =
        find.descendant(of: simPathRow, matching: find.byType(Checkbox));

    expect(simPathCheck, findsOneWidget);

    await widgetTester.tap(simPathCheck);
    await widgetTester.pumpAndSettle();

    expect(prefs.getBool(PrefsKeys.displaySimPath), true);

    await widgetTester.tap(simPathCheck);
    await widgetTester.pumpAndSettle();

    expect(prefs.getBool(PrefsKeys.displaySimPath), false);
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
}
