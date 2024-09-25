import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

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

  num get maxDriveVelocityRadPerSec => maxDriveVelocityMPS / wheelRadiusMeters;
}
