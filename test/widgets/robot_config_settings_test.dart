import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:pathplanner/widgets/robot_config_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late bool settingsChanged;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.robotWidth: 0.9,
      PrefsKeys.robotLength: 0.9,
      PrefsKeys.bumperOffsetX: 0.0,
      PrefsKeys.bumperOffsetY: 0.0,
      PrefsKeys.robotMass: 50.0,
      PrefsKeys.robotMOI: 6.0,
      PrefsKeys.robotTrackwidth: 0.7,
      PrefsKeys.driveWheelRadius: 0.05,
      PrefsKeys.driveGearing: 5.143,
      PrefsKeys.maxDriveSpeed: 5.4,
      PrefsKeys.wheelCOF: 1.2,
      PrefsKeys.driveMotor: 'krakenX60',
      PrefsKeys.driveCurrentLimit: 60.0,
      PrefsKeys.holonomicMode: true,
      PrefsKeys.flModuleX: 0.2,
      PrefsKeys.flModuleY: 0.2,
      PrefsKeys.frModuleX: 0.2,
      PrefsKeys.frModuleY: -0.2,
      PrefsKeys.blModuleX: -0.2,
      PrefsKeys.blModuleY: 0.2,
      PrefsKeys.brModuleX: -0.2,
      PrefsKeys.brModuleY: -0.2,
    });
    prefs = await SharedPreferences.getInstance();
    settingsChanged = false;
  });

  group('robot config', () {
    testWidgets('mass text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField = find.widgetWithText(NumberTextField, 'Robot Mass (KG)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('50.000')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.robotMass), 1.0);
    });

    testWidgets('MOI text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Robot MOI (KG*M²)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('6.000')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.robotMOI), 1.0);
    });

    testWidgets('trackwidth text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      prefs.setBool(PrefsKeys.holonomicMode, false);

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField = find.widgetWithText(NumberTextField, 'Trackwidth (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.700')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.robotTrackwidth), 1.0);
    });
  });

  group('bumpers', () {
    testWidgets('bumper width text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Bumper Width (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.900')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.robotWidth), 1.0);
    });

    testWidgets('bumper length text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Bumper Length (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.900')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.robotLength), 1.0);
    });

    testWidgets('bumper offset x text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Bumper Offset X (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.000')),
          findsOneWidget);

      await widgetTester.enterText(textField, '0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.bumperOffsetX), 0.1);
    });

    testWidgets('bumper offset y text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Bumper Offset Y (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.000')),
          findsOneWidget);

      await widgetTester.enterText(textField, '0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.bumperOffsetY), 0.1);
    });
  });

  group('module config', () {
    testWidgets('wheel radius text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Wheel Radius (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.050')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.driveWheelRadius), 1.0);
    });

    testWidgets('drive gearing text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField = find.widgetWithText(NumberTextField, 'Drive Gearing');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('5.143')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.driveGearing), 1.0);
    });

    testWidgets('max drive speed field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'True Max Drive Speed (M/S)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('5.400')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.maxDriveSpeed), 1.0);
    });

    testWidgets('wheel cof text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField = find.widgetWithText(NumberTextField, 'Wheel COF');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('1.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.wheelCOF), 1.0);
    });

    testWidgets('drive motor dropdown', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final dropdown = find.byType(DropdownButton<String>).first;

      expect(dropdown, findsOneWidget);
      expect(find.descendant(of: dropdown, matching: find.text('Kraken X60')),
          findsOneWidget);

      await widgetTester.tap(dropdown);
      await widgetTester.pumpAndSettle();

      expect(find.text('Kraken X60'), findsWidgets);
      expect(find.text('Kraken X60 FOC'), findsOneWidget);

      await widgetTester.tap(find.text('Kraken X60 FOC'));
      await widgetTester.pumpAndSettle();

      expect(settingsChanged, true);
      expect(prefs.getString(PrefsKeys.driveMotor), 'krakenX60FOC');
      expect(find.text('Kraken X60 FOC'), findsOneWidget);
      expect(find.text('Kraken X60'), findsNothing);
    });

    testWidgets('current limit field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Drive Current Limit (A)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('60')),
          findsOneWidget);

      await widgetTester.enterText(textField, '1.0');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.driveCurrentLimit), 1.0);
    });
  });

  group('module offsets', () {
    testWidgets('front left x text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Front Left X (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.flModuleX), 0.1);
    });

    testWidgets('front left y text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Front Left Y (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.flModuleY), 0.1);
    });

    testWidgets('front right x text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Front Right X (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.frModuleX), 0.1);
    });

    testWidgets('front right y text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Front Right Y (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('-0.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '-0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.frModuleY), -0.1);
    });

    testWidgets('back left x text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField = find.widgetWithText(NumberTextField, 'Back Left X (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('-0.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '-0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.blModuleX), -0.1);
    });

    testWidgets('back left y text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField = find.widgetWithText(NumberTextField, 'Back Left Y (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('0.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.blModuleY), 0.1);
    });

    testWidgets('back right x text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Back Right X (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('-0.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '-0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.brModuleX), -0.1);
    });

    testWidgets('back right y text field', (widgetTester) async {
      await widgetTester.binding.setSurfaceSize(const Size(1280, 1200));

      await widgetTester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RobotConfigSettings(
            onSettingsChanged: () => settingsChanged = true,
            prefs: prefs,
          ),
        ),
      ));

      final textField =
          find.widgetWithText(NumberTextField, 'Back Right Y (M)');

      expect(textField, findsOneWidget);
      expect(find.descendant(of: textField, matching: find.text('-0.200')),
          findsOneWidget);

      await widgetTester.enterText(textField, '-0.1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      expect(settingsChanged, true);
      expect(prefs.getDouble(PrefsKeys.brModuleY), -0.1);
    });
  });
}
