import 'package:pathplanner/util/wpimath/geometry.dart';

class ChassisSpeeds {
  final num vx;
  final num vy;
  final num omega;

  const ChassisSpeeds({
    this.vx = 0,
    this.vy = 0,
    this.omega = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is ChassisSpeeds &&
      other.runtimeType == runtimeType &&
      other.vx == vx &&
      other.vy == vy &&
      other.omega == omega;

  @override
  int get hashCode => Object.hash(vx, vy, omega);
}

class SwerveModuleState {
  num speedMetersPerSecond = 0.0;
  Rotation2d angle = Rotation2d();
}
