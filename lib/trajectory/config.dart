import 'dart:math';

import 'package:pathplanner/trajectory/motor_torque_curve.dart';
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
  final num driveGearing;
  final num maxDriveVelocityRPM;
  final MotorTorqueCurve driveMotorTorqueCurve;
  final num wheelCOF;

  const ModuleConfig({
    required this.wheelRadiusMeters,
    required this.driveGearing,
    required this.maxDriveVelocityRPM,
    required this.driveMotorTorqueCurve,
    required this.wheelCOF,
  });

  num get rpmToMPS =>
      ((1.0 / 60.0) / driveGearing) * (2.0 * pi * wheelRadiusMeters);

  num get maxDriveVelocityMPS => maxDriveVelocityRPM * rpmToMPS;
}
