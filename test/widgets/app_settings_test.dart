import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/app_settings.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late bool settingsChanged;
  FieldImage? selectedField;
  late Color teamColor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.holonomicMode: true,
      PrefsKeys.hotReloadEnabled: true,
      PrefsKeys.teamColor: Colors.black.value,
      PrefsKeys.ntServerAddress: '10.30.15.2',
      PrefsKeys.defaultMaxVel: 1.0,
      PrefsKeys.defaultMaxAccel: 2.0,
      PrefsKeys.defaultMaxAngVel: 3.0,
      PrefsKeys.defaultMaxAngAccel: 4.0,
      PrefsKeys.defaultNominalVoltage: 12.0,
    });
    prefs = await SharedPreferences.getInstance();
    settingsChanged = false;
    selectedField = null;
    teamColor = Colors.black;
  });

  testWidgets('default max vel text field', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField =
        find.widgetWithText(NumberTextField, 'Max Velocity (M/S)');

    expect(textField, findsOneWidget);
    expect(find.descendant(of: textField, matching: find.text('1.000')),
        findsOneWidget);

    await widgetTester.enterText(textField, '1.1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getDouble(PrefsKeys.defaultMaxVel), 1.1);
  });

  testWidgets('default max accel text field', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField =
        find.widgetWithText(NumberTextField, 'Max Acceleration (M/S²)');

    expect(textField, findsOneWidget);
    expect(find.descendant(of: textField, matching: find.text('2.000')),
        findsOneWidget);

    await widgetTester.enterText(textField, '2.2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getDouble(PrefsKeys.defaultMaxAccel), 2.2);
  });

  testWidgets('default max ang vel text field', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField =
        find.widgetWithText(NumberTextField, 'Max Angular Velocity (Deg/S)');

    expect(textField, findsOneWidget);
    expect(find.descendant(of: textField, matching: find.text('3.000')),
        findsOneWidget);

    await widgetTester.enterText(textField, '3.3');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getDouble(PrefsKeys.defaultMaxAngVel), 3.3);
  });

  testWidgets('default max ang accel text field', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField =
        find.widgetWithText(NumberTextField, 'Max Angular Accel (Deg/S²)');

    expect(textField, findsOneWidget);
    expect(find.descendant(of: textField, matching: find.text('4.000')),
        findsOneWidget);

    await widgetTester.enterText(textField, '4.4');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getDouble(PrefsKeys.defaultMaxAngAccel), 4.4);
  });

  testWidgets('default voltage text field', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField =
        find.widgetWithText(NumberTextField, 'Nominal Voltage (Volts)');

    expect(textField, findsOneWidget);
    expect(find.descendant(of: textField, matching: find.text('12.000')),
        findsOneWidget);

    await widgetTester.enterText(textField, '10.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getDouble(PrefsKeys.defaultNominalVoltage), 10.0);
  });

  testWidgets('field image dropdown', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
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
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
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

    expect(teamColor, Colors.black);

    final resetButton = find.text('Reset');

    expect(resetButton, findsOneWidget);

    await widgetTester.tap(resetButton);
    await widgetTester.pumpAndSettle();

    expect(teamColor.value, Defaults.teamColor);
  });

  testWidgets('telemetry host text field', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
          onSettingsChanged: () => settingsChanged = true,
          onFieldSelected: (value) => selectedField = value,
          fieldImages: FieldImage.offialFields(),
          selectedField: FieldImage.official(OfficialField.chargedUp),
          prefs: prefs,
          onTeamColorChanged: (value) => teamColor = value,
        ),
      ),
    ));

    final textField = find.widgetWithText(TextField, 'roboRIO IP (10.TE.AM.2)');

    expect(textField, findsOneWidget);

    await widgetTester.enterText(textField, '10.99.99.2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(settingsChanged, true);
    expect(prefs.getString(PrefsKeys.ntServerAddress), '10.99.99.2');
  });

  testWidgets('holonomic mode chip', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
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
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSettings(
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
