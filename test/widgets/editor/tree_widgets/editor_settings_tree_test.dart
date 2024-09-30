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

  testWidgets('Editor Settings Tree checks', (widgetTester) async {
    await widgetTester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EditorSettingsTree(
          initiallyExpanded: true,
        ),
      ),
    ));
    await widgetTester.pump();

    // List of all settings to test
    final settings = [
      ('Snap To Guidelines', PrefsKeys.snapToGuidelines),
      ('Hide Other Paths on Hover', PrefsKeys.hidePathsOnHover),
      ('Show Trajectory States', PrefsKeys.showStates),
      ('Show Robot Details', PrefsKeys.showRobotDetails),
      ('Show Grid', PrefsKeys.showGrid),
    ];

    for (final setting in settings) {
      final label = setting.$1;
      final prefKey = setting.$2;

      final row = find
          .ancestor(
            of: find.text(label),
            matching: find.byType(Row),
          )
          .first;

      expect(row, findsOneWidget);

      final check = find.descendant(
        of: row,
        matching: find.byType(Checkbox),
      );

      expect(check, findsOneWidget);

      await widgetTester.tap(check);
      await widgetTester.pumpAndSettle();

      expect(prefs.getBool(prefKey), true);

      await widgetTester.tap(check);
      await widgetTester.pumpAndSettle();

      expect(prefs.getBool(prefKey), false);
    }
  });
}
