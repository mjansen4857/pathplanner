import 'dart:math' as math;

import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/simulation/swerve_math.dart';
import 'package:pathplanner/path2/simulation/swerve_module_state.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

class Path2SwerveSetpoint {
  final ChassisSpeeds robotRelativeSpeeds;
  final List<Path2SimulationModuleState> moduleStates;

  Path2SwerveSetpoint({
    required this.robotRelativeSpeeds,
    required List<Path2SimulationModuleState> moduleStates,
  }) : moduleStates = List.unmodifiable(moduleStates);

  factory Path2SwerveSetpoint.atRest({int numModules = 4}) {
    return Path2SwerveSetpoint(
      robotRelativeSpeeds: const ChassisSpeeds(),
      moduleStates: List.filled(
        numModules,
        const Path2SimulationModuleState(),
        growable: false,
      ),
    );
  }

  factory Path2SwerveSetpoint.fromSimulationState(Path2SimulationState state) {
    return Path2SwerveSetpoint(
      robotRelativeSpeeds: state.robotRelativeSpeeds,
      moduleStates: state.moduleStates,
    );
  }

  factory Path2SwerveSetpoint.fromMap(Map<String, dynamic> map) {
    final speeds = Map<String, dynamic>.from(map['robotRelativeSpeeds'] as Map);
    return Path2SwerveSetpoint(
      robotRelativeSpeeds: ChassisSpeeds(
        vx: (speeds['vx'] as num).toDouble(),
        vy: (speeds['vy'] as num).toDouble(),
        omega: (speeds['omega'] as num).toDouble(),
      ),
      moduleStates: (map['moduleStates'] as List<dynamic>)
          .map(
            (state) => Path2SimulationModuleState.fromMap(
              Map<String, dynamic>.from(state as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() => {
    'robotRelativeSpeeds': {
      'vx': robotRelativeSpeeds.vx.toDouble(),
      'vy': robotRelativeSpeeds.vy.toDouble(),
      'omega': robotRelativeSpeeds.omega.toDouble(),
    },
    'moduleStates': moduleStates
        .map((state) => state.toMap())
        .toList(growable: false),
  };
}

/// Limits desired Path2 follower output to the configured swerve drivetrain's
/// kinematic, steering, motor torque, current, and wheel-friction capabilities.
///
/// This is a Dart port of PathPlannerLib's `SwerveSetpointGenerator`, trimmed to
/// the fixed conditions used by the app simulator: a 20 ms loop, 12 V input,
/// four swerve modules, and no additional path-constraint override.
class SwerveSetpointGenerator {
  static const double periodSeconds = 0.02;
  static const double inputVoltage = 12.0;
  static const double maxSteerVelocityRadiansPerSecond = 10.0 * 2.0 * math.pi;

  final Path2RobotConfigSnapshot config;
  final Path2SwerveKinematics _kinematics;

  SwerveSetpointGenerator(this.config)
    : _kinematics = Path2SwerveKinematics(config.moduleLocations);

  factory SwerveSetpointGenerator.fromRobotConfig(RobotConfig config) {
    return SwerveSetpointGenerator(
      Path2RobotConfigSnapshot.fromRobotConfig(config),
    );
  }

  Path2SwerveSetpoint generateSetpoint(
    Path2SwerveSetpoint previousSetpoint,
    ChassisSpeeds desiredRobotRelativeSpeeds,
  ) {
    if (previousSetpoint.moduleStates.length != config.numModules) {
      throw ArgumentError(
        'Previous setpoint has ${previousSetpoint.moduleStates.length} '
        'modules; expected ${config.numModules}',
      );
    }
    if (!Path2SimulationMath.isFiniteChassisSpeeds(
      desiredRobotRelativeSpeeds,
    )) {
      throw ArgumentError('Desired chassis speeds must be finite');
    }

    var desiredModuleStates = List<Path2SimulationModuleState>.of(
      Path2SimulationMath.desaturateWheelSpeeds(
        _kinematics.toModuleStates(desiredRobotRelativeSpeeds),
        config.maxDriveVelocityMetersPerSecond,
      ),
    );
    desiredRobotRelativeSpeeds = _kinematics.toChassisSpeeds(
      desiredModuleStates,
    );

    var needsSteering = true;
    if (Path2SimulationMath.chassisSpeedsEpsilonEquals(
      desiredRobotRelativeSpeeds,
      const ChassisSpeeds(),
    )) {
      needsSteering = false;
      desiredModuleStates = List.generate(
        config.numModules,
        (index) => Path2SimulationModuleState(
          angle: previousSetpoint.moduleStates[index].angle,
        ),
        growable: false,
      );
    }

    final previousVx = List<double>.filled(config.numModules, 0.0);
    final previousVy = List<double>.filled(config.numModules, 0.0);
    final previousHeading = List<Rotation2d>.filled(
      config.numModules,
      const Rotation2d(),
    );
    final desiredVx = List<double>.filled(config.numModules, 0.0);
    final desiredVy = List<double>.filled(config.numModules, 0.0);
    final desiredHeading = List<Rotation2d>.filled(
      config.numModules,
      const Rotation2d(),
    );

    var allModulesShouldFlip = true;
    for (var module = 0; module < config.numModules; module++) {
      final previousState = previousSetpoint.moduleStates[module];
      final desiredState = desiredModuleStates[module];
      previousVx[module] =
          previousState.angle.cosine * previousState.speedMetersPerSecond;
      previousVy[module] =
          previousState.angle.sine * previousState.speedMetersPerSecond;
      previousHeading[module] = previousState.speedMetersPerSecond < 0.0
          ? previousState.angle + Rotation2d.fromRadians(math.pi)
          : previousState.angle;
      desiredVx[module] =
          desiredState.angle.cosine * desiredState.speedMetersPerSecond;
      desiredVy[module] =
          desiredState.angle.sine * desiredState.speedMetersPerSecond;
      desiredHeading[module] = desiredState.speedMetersPerSecond < 0.0
          ? desiredState.angle + Rotation2d.fromRadians(math.pi)
          : desiredState.angle;

      if (allModulesShouldFlip) {
        final requiredRotation =
            (desiredHeading[module] - previousHeading[module]).radians.abs();
        if (requiredRotation < math.pi / 2.0) {
          allModulesShouldFlip = false;
        }
      }
    }

    if (allModulesShouldFlip &&
        !Path2SimulationMath.chassisSpeedsEpsilonEquals(
          previousSetpoint.robotRelativeSpeeds,
          const ChassisSpeeds(),
        ) &&
        !Path2SimulationMath.chassisSpeedsEpsilonEquals(
          desiredRobotRelativeSpeeds,
          const ChassisSpeeds(),
        )) {
      return generateSetpoint(previousSetpoint, const ChassisSpeeds());
    }

    final dx =
        desiredRobotRelativeSpeeds.vx.toDouble() -
        previousSetpoint.robotRelativeSpeeds.vx.toDouble();
    final dy =
        desiredRobotRelativeSpeeds.vy.toDouble() -
        previousSetpoint.robotRelativeSpeeds.vy.toDouble();
    final dtheta =
        desiredRobotRelativeSpeeds.omega.toDouble() -
        previousSetpoint.robotRelativeSpeeds.omega.toDouble();

    var minimumInterpolation = 1.0;
    final steeringOverrides = List<Rotation2d?>.filled(config.numModules, null);

    for (var module = 0; module < config.numModules; module++) {
      final previousState = previousSetpoint.moduleStates[module];
      final desiredState = desiredModuleStates[module];
      if (!needsSteering) {
        steeringOverrides[module] = previousState.angle;
        continue;
      }

      var maxThetaStep = periodSeconds * maxSteerVelocityRadiansPerSecond;
      if (Path2SimulationMath.epsilonEquals(
        previousState.speedMetersPerSecond,
        0.0,
      )) {
        if (Path2SimulationMath.epsilonEquals(
          desiredState.speedMetersPerSecond,
          0.0,
        )) {
          steeringOverrides[module] = previousState.angle;
          continue;
        }

        var necessaryRotation = desiredState.angle - previousState.angle;
        if (_flipHeading(necessaryRotation)) {
          necessaryRotation =
              necessaryRotation + Rotation2d.fromRadians(math.pi);
        }
        final stepsNeeded = necessaryRotation.radians.abs() / maxThetaStep;
        if (stepsNeeded <= 1.0) {
          steeringOverrides[module] = desiredState.angle;
        } else {
          steeringOverrides[module] =
              previousState.angle +
              Rotation2d.fromRadians(
                necessaryRotation.radians.sign * maxThetaStep,
              );
          minimumInterpolation = 0.0;
        }
        continue;
      }
      if (minimumInterpolation == 0.0) {
        continue;
      }

      final maxHeadingChange =
          (periodSeconds * config.wheelFrictionForce) /
          ((config.massKg / config.numModules) *
              previousState.speedMetersPerSecond.abs());
      maxThetaStep = math.min(maxThetaStep, maxHeadingChange);
      final steeringInterpolation = _findSteeringMaxS(
        previousVx[module],
        previousVy[module],
        previousHeading[module].radians.toDouble(),
        desiredVx[module],
        desiredVy[module],
        desiredHeading[module].radians.toDouble(),
        maxThetaStep,
      );
      minimumInterpolation = math.min(
        minimumInterpolation,
        steeringInterpolation,
      );
    }

    var chassisForceVector = const Translation2d();
    var chassisTorque = 0.0;
    final pivotDistances = config.modulePivotDistances;
    for (var module = 0; module < config.numModules; module++) {
      final previousState = previousSetpoint.moduleStates[module];
      final lastVelocityRadiansPerSecond =
          previousState.speedMetersPerSecond / config.wheelRadiusMeters;
      var forwardCurrent = config.motorCurrent(
        lastVelocityRadiansPerSecond.abs(),
        inputVoltage,
      );
      var reverseCurrent = config
          .motorCurrent(lastVelocityRadiansPerSecond.abs(), -inputVoltage)
          .abs();
      forwardCurrent = forwardCurrent
          .clamp(0.0, config.driveCurrentLimitAmps)
          .toDouble();
      reverseCurrent = reverseCurrent
          .clamp(0.0, config.driveCurrentLimitAmps)
          .toDouble();
      final forwardModuleTorque = config.motorTorque(forwardCurrent);
      final reverseModuleTorque = config.motorTorque(reverseCurrent);

      final optimizedDesired = desiredModuleStates[module].optimized(
        previousState.angle,
      );
      desiredModuleStates[module] = optimizedDesired;

      late final int forceSign;
      var forceAngle = previousState.angle;
      late double moduleTorque;
      final previousSpeed = previousState.speedMetersPerSecond;
      final desiredSpeed = optimizedDesired.speedMetersPerSecond;
      if (Path2SimulationMath.epsilonEquals(previousSpeed, 0.0) ||
          (previousSpeed > 0.0 && desiredSpeed >= previousSpeed) ||
          (previousSpeed < 0.0 && desiredSpeed <= previousSpeed)) {
        moduleTorque = forwardModuleTorque - config.torqueLoss;
        forceSign = 1;
        if (previousSpeed < 0.0) {
          forceAngle = forceAngle + Rotation2d.fromRadians(math.pi);
        }
      } else {
        moduleTorque = reverseModuleTorque + config.torqueLoss;
        forceSign = -1;
        if (previousSpeed > 0.0) {
          forceAngle = forceAngle + Rotation2d.fromRadians(math.pi);
        }
      }

      moduleTorque = math.min(moduleTorque, config.maxTorqueBeforeWheelSlip);
      final forceAtCarpet = moduleTorque / config.wheelRadiusMeters;
      final moduleForceVector = Translation2d.fromAngle(
        forceAtCarpet * forceSign,
        forceAngle,
      );
      chassisForceVector = chassisForceVector + moduleForceVector;

      if (!Path2SimulationMath.epsilonEquals(
        moduleForceVector.norm.toDouble(),
        0.0,
      )) {
        final angleToModule = config.moduleLocations[module].angle;
        final theta = moduleForceVector.angle - angleToModule;
        chassisTorque += forceAtCarpet * pivotDistances[module] * theta.sine;
      }
    }

    final chassisAcceleration = ChassisSpeeds(
      vx: chassisForceVector.x / config.massKg,
      vy: chassisForceVector.y / config.massKg,
      omega: chassisTorque / config.momentOfInertiaKgMetersSquared,
    );
    final accelerationStates = _kinematics.toModuleStates(chassisAcceleration);

    for (var module = 0; module < config.numModules; module++) {
      if (minimumInterpolation == 0.0) {
        break;
      }
      final maxVelocityStep =
          (accelerationStates[module].speedMetersPerSecond * periodSeconds)
              .abs();
      final vxAtMinimum = minimumInterpolation == 1.0
          ? desiredVx[module]
          : (desiredVx[module] - previousVx[module]) * minimumInterpolation +
                previousVx[module];
      final vyAtMinimum = minimumInterpolation == 1.0
          ? desiredVy[module]
          : (desiredVy[module] - previousVy[module]) * minimumInterpolation +
                previousVy[module];
      final driveInterpolation = _findDriveMaxS(
        previousVx[module],
        previousVy[module],
        vxAtMinimum,
        vyAtMinimum,
        maxVelocityStep,
      );
      minimumInterpolation = math.min(minimumInterpolation, driveInterpolation);
    }

    var returnedSpeeds = ChassisSpeeds(
      vx: previousSetpoint.robotRelativeSpeeds.vx + minimumInterpolation * dx,
      vy: previousSetpoint.robotRelativeSpeeds.vy + minimumInterpolation * dy,
      omega:
          previousSetpoint.robotRelativeSpeeds.omega +
          minimumInterpolation * dtheta,
    );
    returnedSpeeds = Path2SimulationMath.discretizeChassisSpeeds(
      returnedSpeeds,
      periodSeconds,
    );

    final returnedStates = _kinematics.toModuleStates(returnedSpeeds);
    for (var module = 0; module < config.numModules; module++) {
      var returnedState = returnedStates[module];
      final steeringOverride = steeringOverrides[module];
      if (steeringOverride != null) {
        var speed = returnedState.speedMetersPerSecond;
        if (_flipHeading(steeringOverride - returnedState.angle)) {
          speed *= -1.0;
        }
        returnedState = Path2SimulationModuleState(
          speedMetersPerSecond: speed,
          angle: steeringOverride,
        );
      }

      final deltaRotation =
          returnedState.angle - previousSetpoint.moduleStates[module].angle;
      if (_flipHeading(deltaRotation)) {
        returnedState = Path2SimulationModuleState(
          speedMetersPerSecond: -returnedState.speedMetersPerSecond,
          angle: returnedState.angle + Rotation2d.fromRadians(math.pi),
        );
      }
      returnedStates[module] = returnedState;
    }

    return Path2SwerveSetpoint(
      robotRelativeSpeeds: returnedSpeeds,
      moduleStates: returnedStates,
    );
  }

  static bool _flipHeading(Rotation2d previousToGoal) =>
      previousToGoal.radians.abs() > math.pi / 2.0;

  static double _unwrapAngle(double reference, double angle) {
    final difference = angle - reference;
    if (difference > math.pi) {
      return angle - 2.0 * math.pi;
    }
    if (difference < -math.pi) {
      return angle + 2.0 * math.pi;
    }
    return angle;
  }

  static double _findSteeringMaxS(
    double x0,
    double y0,
    double theta0,
    double x1,
    double y1,
    double theta1,
    double maxDeviation,
  ) {
    theta1 = _unwrapAngle(theta0, theta1);
    final difference = theta1 - theta0;
    if (difference.abs() <= maxDeviation) {
      return 1.0;
    }

    final target = theta0 + difference.sign * maxDeviation;
    final sine = math.sin(-target);
    final cosine = math.cos(-target);
    final h0 = sine * x0 + cosine * y0;
    final h1 = sine * x1 + cosine * y1;
    return h0 / (h0 - h1);
  }

  static bool _isValidS(double interpolation) =>
      interpolation.isFinite && interpolation >= 0.0 && interpolation <= 1.0;

  static double _findDriveMaxS(
    double x0,
    double y0,
    double x1,
    double y1,
    double maxVelocityStep,
  ) {
    final lengthSquared0 = x0 * x0 + y0 * y0;
    final lengthSquared1 = x1 * x1 + y1 * y1;
    final length0 = math.sqrt(lengthSquared0);
    final difference = math.sqrt(lengthSquared1) - length0;
    if (difference.abs() <= maxVelocityStep) {
      return 1.0;
    }

    final target = length0 + difference.sign * maxVelocityStep;
    final dotProduct = x0 * x1 + y0 * y1;
    final a = lengthSquared0 + lengthSquared1 - 2.0 * dotProduct;
    final b = 2.0 * (dotProduct - lengthSquared0);
    final c = lengthSquared0 - target * target;
    final root = math.sqrt(b * b - 4.0 * a * c);

    final firstSolution = (-b + root) / (2.0 * a);
    if (_isValidS(firstSolution)) {
      return firstSolution;
    }
    final secondSolution = (-b - root) / (2.0 * a);
    if (_isValidS(secondSolution)) {
      return secondSolution;
    }
    return 1.0;
  }
}
