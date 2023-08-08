import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/dialogs/settings_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late bool settingsChanged;
  FieldImage? selectedField;
  Color? teamColor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.robotWidth: 0.1,
      PrefsKeys.robotLength: 0.2,
      PrefsKeys.holonomicMode: true,
      PrefsKeys.hotReloadEnabled: true,
      PrefsKeys.teamColor: Colors.black.value,
      PrefsKeys.pplibClientHost: 'localhost',
    });
    prefs = await SharedPreferences.getInstance();
    settingsChanged = false;
    selectedField = null;
    teamColor = null;
  });

  testWidgets('robot width text field', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Width (M)');

    expect(textField, findsOneWidget);
    expect(find.descendant(of: textField, matching: find.text('0.10')),
        findsOneWidget);

    await widgetTester.enterText(textField, '1.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getDouble(PrefsKeys.robotWidth), 1.0);
  });

  testWidgets('robot length text field', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField = find.widgetWithText(NumberTextField, 'Length (M)');

    expect(textField, findsOneWidget);
    expect(find.descendant(of: textField, matching: find.text('0.20')),
        findsOneWidget);

    await widgetTester.enterText(textField, '1.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getDouble(PrefsKeys.robotLength), 1.0);
  });

  testWidgets('field image dropdown', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final dropdown = find.byType(DropdownButton<FieldImage?>);

    expect(dropdown, findsOneWidget);
    expect(find.descendant(of: dropdown, matching: find.text('Charged Up')),
        findsOneWidget);

    await widgetTester.tap(dropdown);
    await widgetTester.pumpAndSettle();

    expect(find.text('Charged Up'), findsWidgets);
    expect(find.text('Rapid React'), findsOneWidget);
    expect(find.text('Import Custom...'), findsOneWidget);

    await widgetTester.tap(find.text('Rapid React'));
    await widgetTester.pumpAndSettle();

    expect(selectedField, FieldImage.official(OfficialField.rapidReact));
    expect(find.text('Rapid React'), findsOneWidget);
    expect(find.text('Charged Up'), findsNothing);
  });

  testWidgets('team color picker', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final pickerButton = find.byType(ElevatedButton);

    expect(pickerButton, findsOneWidget);

    await widgetTester.tap(pickerButton);
    await widgetTester.pumpAndSettle();

    final confirmButton = find.text('Confirm');

    expect(confirmButton, findsOneWidget);

    await widgetTester.tap(confirmButton);
    await widgetTester.pumpAndSettle();

    expect(teamColor, Colors.black);

    await widgetTester.tap(pickerButton);
    await widgetTester.pumpAndSettle();

    final resetButton = find.text('Reset');

    expect(resetButton, findsOneWidget);

    await widgetTester.tap(resetButton);
    await widgetTester.pumpAndSettle();

    expect(teamColor?.value, Defaults.teamColor);
  });

  testWidgets('telemetry host text field', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField = find.widgetWithText(TextField, 'Host');

    expect(textField, findsOneWidget);
    expect(find.descendant(of: textField, matching: find.text('localhost')),
        findsOneWidget);

    await widgetTester.enterText(textField, '10.30.15.2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getString(PrefsKeys.pplibClientHost), '10.30.15.2');
  });

  testWidgets('holonomic mode chip', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final chip = find.widgetWithText(FilterChip, 'Holonomic Mode');

    expect(chip, findsOneWidget);

    await widgetTester.tap(chip);
    await widgetTester.pumpAndSettle();

    expect(settingsChanged, true);
    expect(prefs.getBool(PrefsKeys.holonomicMode), false);

    await widgetTester.tap(chip);
    await widgetTester.pumpAndSettle();

    expect(prefs.getBool(PrefsKeys.holonomicMode), true);
  });

  testWidgets('hot reload chip', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final chip = find.widgetWithText(FilterChip, 'Hot Reload');

    expect(chip, findsOneWidget);

    await widgetTester.tap(chip);
    await widgetTester.pumpAndSettle();

    expect(settingsChanged, true);
    expect(prefs.getBool(PrefsKeys.hotReloadEnabled), false);

    await widgetTester.tap(chip);
    await widgetTester.pumpAndSettle();

    expect(prefs.getBool(PrefsKeys.hotReloadEnabled), true);
  });
}
