import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'RobotConfig.fromPrefs always creates a four-module swerve config',
    () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.holonomicMode: false,
        PrefsKeys.robotTrackwidth: 1.5,
        PrefsKeys.driveCurrentLimit: 47.0,
        PrefsKeys.flModuleX: 0.31,
        PrefsKeys.flModuleY: 0.32,
        PrefsKeys.frModuleX: 0.33,
        PrefsKeys.frModuleY: -0.34,
        PrefsKeys.blModuleX: -0.35,
        PrefsKeys.blModuleY: 0.36,
        PrefsKeys.brModuleX: -0.37,
        PrefsKeys.brModuleY: -0.38,
      });
      final prefs = await SharedPreferences.getInstance();

      final config = RobotConfig.fromPrefs(prefs);

      expect(config.holonomic, true);
      expect(config.moduleLocations, hasLength(4));
      expect(config.moduleLocations[0].x, 0.31);
      expect(config.moduleLocations[0].y, 0.32);
      expect(config.moduleLocations[1].x, 0.33);
      expect(config.moduleLocations[1].y, -0.34);
      expect(config.moduleLocations[2].x, -0.35);
      expect(config.moduleLocations[2].y, 0.36);
      expect(config.moduleLocations[3].x, -0.37);
      expect(config.moduleLocations[3].y, -0.38);
      expect(config.moduleConfig.driveCurrentLimit, 47.0);
      expect(prefs.getBool(PrefsKeys.holonomicMode), true);
      expect(prefs.getDouble(PrefsKeys.robotTrackwidth), 1.5);
    },
  );
  test('friction current defaults to zero and ignores legacy speed', () async {
    SharedPreferences.setMockInitialValues({'maxDriveSpeed': 0.1});
    final prefs = await SharedPreferences.getInstance();
    final config = RobotConfig.fromPrefs(prefs);
    final module = config.moduleConfig;
    expect(module.frictionTorqueCurrent, 0.0);
    expect(
      module.driveMotor.getCurrent(module.maxDriveVelocityRadPerSec, 12.0),
      closeTo(0.0, 1e-9),
    );
    expect(Path2RobotConfigSnapshot.fromRobotConfig(config).torqueLoss, 0.0);
  });

  test(
    'configured friction sets equilibrium speed and survives serialization',
    () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.frictionTorqueCurrent: 15.0,
      });
      final prefs = await SharedPreferences.getInstance();
      final config = RobotConfig.fromPrefs(prefs);
      final module = config.moduleConfig;
      expect(module.frictionTorqueCurrent, 15.0);
      expect(
        module.driveMotor.getCurrent(module.maxDriveVelocityRadPerSec, 12.0),
        closeTo(15.0, 1e-9),
      );
      final snapshot = Path2RobotConfigSnapshot.fromMap(
        Path2RobotConfigSnapshot.fromRobotConfig(config).toMap(),
      );
      expect(snapshot.frictionTorqueCurrentAmps, 15.0);
      expect(
        snapshot.torqueLoss,
        closeTo(module.driveMotor.getTorque(15.0), 1e-9),
      );
      await prefs.setDouble(PrefsKeys.frictionTorqueCurrent, 30.0);
      expect(
        ModuleConfig.fromPrefs(prefs, 1).maxDriveVelocityMPS,
        lessThan(module.maxDriveVelocityMPS),
      );
    },
  );
}
