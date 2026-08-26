import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/trajectory/config.dart';
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
}
