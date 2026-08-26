import 'dart:math' as math;

import 'package:pathplanner/util/wpimath/geometry.dart';

/// The speed and steering angle of one swerve module during a Path2
/// simulation.
///
/// Unlike the mutable WPILib compatibility type used by trajectory generation,
/// this type is immutable so simulation states can be safely shared between
/// animation code and background isolates.
class Path2SimulationModuleState {
  final double speedMetersPerSecond;
  final Rotation2d angle;

  const Path2SimulationModuleState({
    this.speedMetersPerSecond = 0.0,
    this.angle = const Rotation2d(),
  });

  factory Path2SimulationModuleState.fromMap(Map<String, dynamic> map) {
    return Path2SimulationModuleState(
      speedMetersPerSecond:
          (map['speedMetersPerSecond'] as num?)?.toDouble() ?? 0.0,
      angle: Rotation2d.fromRadians(
        (map['angleRadians'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  /// Returns the equivalent state that requires at most 90 degrees of
  /// steering travel from [currentAngle].
  Path2SimulationModuleState optimized(Rotation2d currentAngle) {
    final delta = angle - currentAngle;
    if (delta.radians.abs() > math.pi / 2.0) {
      return Path2SimulationModuleState(
        speedMetersPerSecond: -speedMetersPerSecond,
        angle: angle + Rotation2d.fromRadians(math.pi),
      );
    }
    return this;
  }

  Path2SimulationModuleState interpolate(
    Path2SimulationModuleState endValue,
    double t,
  ) {
    final clampedT = t.clamp(0.0, 1.0);
    return Path2SimulationModuleState(
      speedMetersPerSecond:
          speedMetersPerSecond +
          (endValue.speedMetersPerSecond - speedMetersPerSecond) * clampedT,
      angle: angle.interpolate(endValue.angle, clampedT),
    );
  }

  Map<String, dynamic> toMap() => {
    'speedMetersPerSecond': speedMetersPerSecond,
    'angleRadians': angle.radians.toDouble(),
  };

  @override
  bool operator ==(Object other) {
    return other is Path2SimulationModuleState &&
        other.speedMetersPerSecond == speedMetersPerSecond &&
        other.angle == angle;
  }

  @override
  int get hashCode => Object.hash(speedMetersPerSecond, angle);

  @override
  String toString() {
    return 'Path2SimulationModuleState('
        'speed: ${speedMetersPerSecond.toStringAsFixed(3)}, angle: $angle)';
  }
}
