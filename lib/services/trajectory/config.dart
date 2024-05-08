import 'dart:math';

import 'package:pathplanner/services/trajectory/motor_torque_curve.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

class RobotConfig {
  final num massKG;
  final num moi;
  final ModuleConfig moduleConfig;
  final SwerveDriveKinematics kinematics;
  final List<Translation2d> moduleLocations;

  const RobotConfig({
    required this.massKG,
    required this.moi,
    required this.moduleConfig,
    required this.kinematics,
    required this.moduleLocations,
  });
}

class ModuleConfig {
  final num wheelRadiusMeters;
  final num driveGearing;
  final num maxDriveVelocityMPS;
  final MotorTorqueCurve driveMotorTorqueCurve;
  final num wheelCOF;

  const ModuleConfig({
    required this.wheelRadiusMeters,
    required this.driveGearing,
    required this.maxDriveVelocityMPS,
    required this.driveMotorTorqueCurve,
    required this.wheelCOF,
  });

  num get rpmToMPS =>
      ((1.0 / 60.0) / driveGearing) * (2.0 * pi * wheelRadiusMeters);

  num get maxDriveVelocityRPM => maxDriveVelocityMPS / rpmToMPS;
}
