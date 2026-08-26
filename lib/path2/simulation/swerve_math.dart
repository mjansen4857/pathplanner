import 'dart:math' as math;

import 'package:pathplanner/path2/simulation/swerve_module_state.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart' as wpilib;

class Path2Twist2d {
  final double dx;
  final double dy;
  final double dtheta;

  const Path2Twist2d({this.dx = 0.0, this.dy = 0.0, this.dtheta = 0.0});
}

/// WPILib-compatible math operations needed by the Path2 simulator.
abstract final class Path2SimulationMath {
  static const double epsilon = 1e-6;

  static double angleModulus(double radians) =>
      math.atan2(math.sin(radians), math.cos(radians));

  static bool epsilonEquals(double a, double b, [double tolerance = epsilon]) {
    return (a - b).abs() <= tolerance;
  }

  static bool chassisSpeedsEpsilonEquals(
    wpilib.ChassisSpeeds a,
    wpilib.ChassisSpeeds b, [
    double tolerance = epsilon,
  ]) {
    return epsilonEquals(a.vx.toDouble(), b.vx.toDouble(), tolerance) &&
        epsilonEquals(a.vy.toDouble(), b.vy.toDouble(), tolerance) &&
        epsilonEquals(a.omega.toDouble(), b.omega.toDouble(), tolerance);
  }

  /// WPILib's chassis-speed discretization operation.
  ///
  /// The returned constant twist produces the requested finite transform over
  /// [dtSeconds], correcting the translational skew caused by simultaneous
  /// rotation.
  static wpilib.ChassisSpeeds discretizeChassisSpeeds(
    wpilib.ChassisSpeeds continuousSpeeds,
    double dtSeconds,
  ) {
    if (!dtSeconds.isFinite || dtSeconds <= 0.0) {
      throw ArgumentError.value(dtSeconds, 'dtSeconds', 'must be positive');
    }
    final desiredDelta = Pose2d(
      Translation2d(
        continuousSpeeds.vx * dtSeconds,
        continuousSpeeds.vy * dtSeconds,
      ),
      Rotation2d.fromRadians(continuousSpeeds.omega * dtSeconds),
    );
    final twist = poseLog(
      const Pose2d(Translation2d(), Rotation2d()),
      desiredDelta,
    );
    return wpilib.ChassisSpeeds(
      vx: twist.dx / dtSeconds,
      vy: twist.dy / dtSeconds,
      omega: twist.dtheta / dtSeconds,
    );
  }

  /// Integrates robot-relative chassis speeds through an SE(2) exponential.
  static Pose2d integratePose(
    Pose2d pose,
    wpilib.ChassisSpeeds robotRelativeSpeeds,
    double dtSeconds,
  ) {
    if (!dtSeconds.isFinite || dtSeconds < 0.0) {
      throw ArgumentError.value(dtSeconds, 'dtSeconds', 'must be non-negative');
    }
    return poseExp(
      pose,
      Path2Twist2d(
        dx: robotRelativeSpeeds.vx.toDouble() * dtSeconds,
        dy: robotRelativeSpeeds.vy.toDouble() * dtSeconds,
        dtheta: robotRelativeSpeeds.omega.toDouble() * dtSeconds,
      ),
    );
  }

  static Pose2d poseExp(Pose2d pose, Path2Twist2d twist) {
    final dtheta = twist.dtheta;
    late final double sinThetaOverTheta;
    late final double oneMinusCosThetaOverTheta;
    if (dtheta.abs() < 1e-9) {
      sinThetaOverTheta = 1.0 - dtheta * dtheta / 6.0;
      oneMinusCosThetaOverTheta =
          dtheta / 2.0 - dtheta * dtheta * dtheta / 24.0;
    } else {
      sinThetaOverTheta = math.sin(dtheta) / dtheta;
      oneMinusCosThetaOverTheta = (1.0 - math.cos(dtheta)) / dtheta;
    }

    final transformTranslation = Translation2d(
      twist.dx * sinThetaOverTheta - twist.dy * oneMinusCosThetaOverTheta,
      twist.dx * oneMinusCosThetaOverTheta + twist.dy * sinThetaOverTheta,
    );
    return Pose2d(
      pose.translation + transformTranslation.rotateBy(pose.rotation),
      pose.rotation + Rotation2d.fromRadians(dtheta),
    );
  }

  /// Returns the robot-relative twist taking [start] to [end].
  static Path2Twist2d poseLog(Pose2d start, Pose2d end) {
    final relativeTranslation = (end.translation - start.translation).rotateBy(
      -start.rotation,
    );
    final dtheta = (end.rotation - start.rotation).radians.toDouble();

    late final double sinThetaOverTheta;
    late final double oneMinusCosThetaOverTheta;
    if (dtheta.abs() < 1e-9) {
      sinThetaOverTheta = 1.0 - dtheta * dtheta / 6.0;
      oneMinusCosThetaOverTheta =
          dtheta / 2.0 - dtheta * dtheta * dtheta / 24.0;
    } else {
      sinThetaOverTheta = math.sin(dtheta) / dtheta;
      oneMinusCosThetaOverTheta = (1.0 - math.cos(dtheta)) / dtheta;
    }
    final determinant =
        sinThetaOverTheta * sinThetaOverTheta +
        oneMinusCosThetaOverTheta * oneMinusCosThetaOverTheta;

    return Path2Twist2d(
      dx:
          (sinThetaOverTheta * relativeTranslation.x +
              oneMinusCosThetaOverTheta * relativeTranslation.y) /
          determinant,
      dy:
          (-oneMinusCosThetaOverTheta * relativeTranslation.x +
              sinThetaOverTheta * relativeTranslation.y) /
          determinant,
      dtheta: dtheta,
    );
  }

  static List<Path2SimulationModuleState> desaturateWheelSpeeds(
    List<Path2SimulationModuleState> moduleStates,
    double attainableMaxSpeedMetersPerSecond,
  ) {
    if (!attainableMaxSpeedMetersPerSecond.isFinite ||
        attainableMaxSpeedMetersPerSecond < 0.0) {
      throw ArgumentError.value(
        attainableMaxSpeedMetersPerSecond,
        'attainableMaxSpeedMetersPerSecond',
        'must be finite and non-negative',
      );
    }
    final realMaxSpeed = moduleStates.fold<double>(
      0.0,
      (maximum, state) => math.max(maximum, state.speedMetersPerSecond.abs()),
    );
    if (realMaxSpeed <= attainableMaxSpeedMetersPerSecond ||
        realMaxSpeed <= epsilon) {
      return List.unmodifiable(moduleStates);
    }
    final scale = attainableMaxSpeedMetersPerSecond / realMaxSpeed;
    return List.unmodifiable(
      moduleStates.map(
        (state) => Path2SimulationModuleState(
          speedMetersPerSecond: state.speedMetersPerSecond * scale,
          angle: state.angle,
        ),
      ),
    );
  }

  static bool isFinitePose(Pose2d pose) =>
      pose.x.toDouble().isFinite &&
      pose.y.toDouble().isFinite &&
      pose.rotation.radians.toDouble().isFinite;

  static bool isFiniteChassisSpeeds(wpilib.ChassisSpeeds speeds) =>
      speeds.vx.toDouble().isFinite &&
      speeds.vy.toDouble().isFinite &&
      speeds.omega.toDouble().isFinite;
}

/// A type-safe adapter around the existing swerve kinematics implementation.
class Path2SwerveKinematics {
  final wpilib.SwerveDriveKinematics _kinematics;
  final int numModules;

  Path2SwerveKinematics(List<Translation2d> moduleLocations)
    : numModules = moduleLocations.length,
      _kinematics = wpilib.SwerveDriveKinematics(moduleLocations);

  List<Path2SimulationModuleState> toModuleStates(
    wpilib.ChassisSpeeds chassisSpeeds,
  ) {
    return _kinematics
        .toSwerveModuleStates(chassisSpeeds)
        .map(
          (state) => Path2SimulationModuleState(
            speedMetersPerSecond: state.speedMetersPerSecond.toDouble(),
            angle: state.angle,
          ),
        )
        .toList(growable: false);
  }

  wpilib.ChassisSpeeds toChassisSpeeds(
    List<Path2SimulationModuleState> moduleStates,
  ) {
    if (moduleStates.length != numModules) {
      throw ArgumentError(
        'Expected $numModules module states, got ${moduleStates.length}',
      );
    }
    final compatibilityStates = moduleStates
        .map((state) {
          final converted = wpilib.SwerveModuleState();
          converted.speedMetersPerSecond = state.speedMetersPerSecond;
          converted.angle = state.angle;
          return converted;
        })
        .toList(growable: false);
    return _kinematics.toChassisSpeeds(compatibilityStates);
  }
}
