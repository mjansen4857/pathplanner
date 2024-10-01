import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RobotConfig {
  final num massKG;
  final num moi;
  final ModuleConfig moduleConfig;
  final List<Translation2d> moduleLocations;
  final bool holonomic;
  late final SwerveDriveKinematics kinematics;

  RobotConfig({
    required this.massKG,
    required this.moi,
    required this.moduleConfig,
    required this.moduleLocations,
    required this.holonomic,
  }) : kinematics = SwerveDriveKinematics(moduleLocations);

  factory RobotConfig.fromPrefs(SharedPreferences prefs) {
    bool holonomicMode =
        prefs.getBool(PrefsKeys.holonomicMode) ?? Defaults.holonomicMode;
    int numMotors = holonomicMode ? 1 : 2;
    ModuleConfig moduleConfig = ModuleConfig.fromPrefs(prefs, numMotors);
    num halfWheelbase =
        (prefs.getDouble(PrefsKeys.robotWheelbase) ?? Defaults.robotWheelbase) /
            2;
    num halfTrackwidth = (prefs.getDouble(PrefsKeys.robotTrackwidth) ??
            Defaults.robotTrackwidth) /
        2;
    List<Translation2d> moduleLocations = holonomicMode
        ? [
            Translation2d(halfWheelbase, halfTrackwidth),
            Translation2d(halfWheelbase, -halfTrackwidth),
            Translation2d(-halfWheelbase, halfTrackwidth),
            Translation2d(-halfWheelbase, -halfTrackwidth),
          ]
        : [
            Translation2d(0, halfTrackwidth),
            Translation2d(0, -halfTrackwidth),
          ];

    return RobotConfig(
      massKG: prefs.getDouble(PrefsKeys.robotMass) ?? Defaults.robotMass,
      moi: prefs.getDouble(PrefsKeys.robotMOI) ?? Defaults.robotMOI,
      moduleConfig: moduleConfig,
      moduleLocations: moduleLocations,
      holonomic: holonomicMode,
    );
  }
}

class ModuleConfig {
  final num wheelRadiusMeters;
  final num maxDriveVelocityMPS;
  final DCMotor driveMotor;
  final num driveCurrentLimit;
  final num wheelCOF;

  const ModuleConfig({
    required this.wheelRadiusMeters,
    required this.maxDriveVelocityMPS,
    required this.driveMotor,
    required this.driveCurrentLimit,
    required this.wheelCOF,
  });

  ModuleConfig.fromPrefs(SharedPreferences prefs, int numMotors)
      : this(
          wheelRadiusMeters: prefs.getDouble(PrefsKeys.driveWheelRadius) ??
              Defaults.driveWheelRadius,
          maxDriveVelocityMPS: prefs.getDouble(PrefsKeys.maxDriveSpeed) ??
              Defaults.maxDriveSpeed,
          driveMotor: DCMotor.fromString(
                  prefs.getString(PrefsKeys.driveMotor) ?? Defaults.driveMotor,
                  numMotors)
              .withReduction(prefs.getDouble(PrefsKeys.driveGearing) ??
                  Defaults.driveGearing),
          driveCurrentLimit: (prefs.getDouble(PrefsKeys.driveCurrentLimit) ??
                  Defaults.driveCurrentLimit) *
              numMotors,
          wheelCOF: prefs.getDouble(PrefsKeys.wheelCOF) ?? Defaults.wheelCOF,
        );

  num get maxDriveVelocityRadPerSec => maxDriveVelocityMPS / wheelRadiusMeters;
}
