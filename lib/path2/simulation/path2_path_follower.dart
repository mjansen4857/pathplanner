import 'dart:math' as math;

import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

/// Primitive-only constraints used by the Path2 simulation isolate.
class Path2SimulationConstraints {
  final double maxVelocity;
  final double maxAngularVelocityRadiansPerSecond;
  final double maxAngularAccelerationRadiansPerSecondSquared;

  const Path2SimulationConstraints({
    required this.maxVelocity,
    required this.maxAngularVelocityRadiansPerSecond,
    required this.maxAngularAccelerationRadiansPerSecondSquared,
  });

  factory Path2SimulationConstraints.fromWaypoint(Waypoint waypoint) {
    return Path2SimulationConstraints(
      maxVelocity: waypoint.maxVelocity.toDouble(),
      maxAngularVelocityRadiansPerSecond:
          _degreesToRadians(waypoint.maxAngularVelocity.toDouble()),
      maxAngularAccelerationRadiansPerSecondSquared:
          _degreesToRadians(waypoint.maxAngularAcceleration.toDouble()),
    );
  }

  factory Path2SimulationConstraints.fromMap(Map<String, dynamic> map) {
    return Path2SimulationConstraints(
      maxVelocity: (map['maxVelocity'] as num).toDouble(),
      maxAngularVelocityRadiansPerSecond:
          (map['maxAngularVelocityRadiansPerSecond'] as num).toDouble(),
      maxAngularAccelerationRadiansPerSecondSquared:
          (map['maxAngularAccelerationRadiansPerSecondSquared'] as num)
              .toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'maxVelocity': maxVelocity,
        'maxAngularVelocityRadiansPerSecond':
            maxAngularVelocityRadiansPerSecond,
        'maxAngularAccelerationRadiansPerSecondSquared':
            maxAngularAccelerationRadiansPerSecondSquared,
      };
}

/// A file-system-free waypoint used by the deterministic Path2 simulator.
class Path2SimulationWaypoint {
  final Translation2d position;
  final Rotation2d? rotation;
  final double maxVelocity;
  final double handoffDistance;
  final double maxAngularVelocityRadiansPerSecond;
  final double maxAngularAccelerationRadiansPerSecondSquared;

  const Path2SimulationWaypoint({
    required this.position,
    required this.rotation,
    required this.maxVelocity,
    required this.handoffDistance,
    required this.maxAngularVelocityRadiansPerSecond,
    required this.maxAngularAccelerationRadiansPerSecondSquared,
  });

  Path2SimulationConstraints get constraints => Path2SimulationConstraints(
        maxVelocity: maxVelocity,
        maxAngularVelocityRadiansPerSecond: maxAngularVelocityRadiansPerSecond,
        maxAngularAccelerationRadiansPerSecondSquared:
            maxAngularAccelerationRadiansPerSecondSquared,
      );

  factory Path2SimulationWaypoint.fromWaypoint(
    Waypoint waypoint, {
    required num handoffDistance,
  }) {
    return Path2SimulationWaypoint(
      position: waypoint.position,
      rotation: waypoint is PoseWaypoint ? waypoint.rotation : null,
      maxVelocity: waypoint.maxVelocity.toDouble(),
      handoffDistance: handoffDistance.toDouble(),
      maxAngularVelocityRadiansPerSecond:
          _degreesToRadians(waypoint.maxAngularVelocity.toDouble()),
      maxAngularAccelerationRadiansPerSecondSquared:
          _degreesToRadians(waypoint.maxAngularAcceleration.toDouble()),
    );
  }

  factory Path2SimulationWaypoint.fromMap(Map<String, dynamic> map) {
    final rotation = map['rotationRadians'];
    return Path2SimulationWaypoint(
      position: Translation2d(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
      ),
      rotation:
          rotation is num ? Rotation2d.fromRadians(rotation.toDouble()) : null,
      maxVelocity: (map['maxVelocity'] as num).toDouble(),
      handoffDistance: (map['handoffDistance'] as num).toDouble(),
      maxAngularVelocityRadiansPerSecond:
          (map['maxAngularVelocityRadiansPerSecond'] as num).toDouble(),
      maxAngularAccelerationRadiansPerSecondSquared:
          (map['maxAngularAccelerationRadiansPerSecondSquared'] as num)
              .toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'x': position.x.toDouble(),
        'y': position.y.toDouble(),
        'rotationRadians': rotation?.radians.toDouble(),
        'maxVelocity': maxVelocity,
        'handoffDistance': handoffDistance,
        'maxAngularVelocityRadiansPerSecond':
            maxAngularVelocityRadiansPerSecond,
        'maxAngularAccelerationRadiansPerSecondSquared':
            maxAngularAccelerationRadiansPerSecondSquared,
      };
}

/// The controller portion of the supplied `FollowDynamicPath` command.
///
/// Robot lifecycle, alliance flipping, arbitrary Boolean handoff conditions,
/// beaching, and subsystem output have deliberately been left out. The caller
/// passes the returned robot-relative speeds through the swerve setpoint
/// generator before integrating the simulated robot state.
class Path2PathFollower {
  static const double periodSeconds = 0.02;

  final List<Path2SimulationWaypoint> waypoints;
  final double endToleranceMeters;
  final double endAngleToleranceRadians;

  final _PidController _translationController =
      _PidController(4.0, periodSeconds);
  final _PidController _crossTrackController =
      _PidController(2.0, periodSeconds);
  late final _ProfiledPidController _rotationController;

  late int _targetWaypointIndex;
  late Translation2d _segmentStart;
  late Translation2d _segmentEnd;
  Rotation2d? _heldHeading;

  Path2PathFollower({
    required this.waypoints,
    required this.endToleranceMeters,
    required this.endAngleToleranceRadians,
    required Pose2d initialPose,
    required ChassisSpeeds initialRobotRelativeSpeeds,
    required bool targetFirstWaypoint,
  }) {
    if (waypoints.isEmpty) {
      throw ArgumentError.value(waypoints, 'waypoints', 'Must not be empty');
    }

    _targetWaypointIndex = targetFirstWaypoint || waypoints.length == 1 ? 0 : 1;
    _segmentStart = targetFirstWaypoint
        ? initialPose.translation
        : waypoints.first.position;
    _segmentEnd = waypoints[_targetWaypointIndex].position;

    final constraints = _trapezoidConstraints(
      waypoints[_targetWaypointIndex].constraints,
    );
    _rotationController = _ProfiledPidController(
      5.0,
      periodSeconds,
      constraints,
    )
      ..enableContinuousInput(-math.pi, math.pi)
      ..setTolerance(endAngleToleranceRadians)
      ..reset(initialPose.rotation.radians.toDouble(),
          initialRobotRelativeSpeeds.omega.toDouble());

    _translationController
      ..setTolerance(endToleranceMeters)
      ..reset();
    _crossTrackController
      ..setTolerance(endToleranceMeters)
      ..reset();
    _updateHeldHeading(initialPose.rotation);
  }

  int get targetWaypointIndex => _targetWaypointIndex;

  bool get isFinished =>
      _targetWaypointIndex == waypoints.length - 1 &&
      _translationController.atSetpoint &&
      _rotationController.atSetpoint;

  /// Calculate the unconstrained robot-relative request for one 20 ms tick.
  ChassisSpeeds calculate(
    Pose2d currentPose, [
    ChassisSpeeds currentRobotRelativeSpeeds = const ChassisSpeeds(),
  ]) {
    _advanceTargetIfNeeded(currentPose);
    final activeConstraints = waypoints[_targetWaypointIndex].constraints;
    _rotationController.setConstraints(
      _trapezoidConstraints(activeConstraints),
    );

    final remainingDistance = _calculateRemainingPathDistance(currentPose);
    final toTarget = _segmentEnd - currentPose.translation;
    final angleToTarget = toTarget.angle;

    var translationOutput =
        -_translationController.calculate(remainingDistance, 0.0);
    final maxVelocity = activeConstraints.maxVelocity;
    translationOutput =
        translationOutput.clamp(-maxVelocity, maxVelocity).toDouble();

    var vx = translationOutput * angleToTarget.cosine;
    var vy = translationOutput * angleToTarget.sine;

    final crossTrackOutput = -_crossTrackController.calculate(
        _calculateCrossTrackError(currentPose), 0.0);
    final perpendicular = angleToTarget - Rotation2d.fromRadians(math.pi / 2.0);
    vx += crossTrackOutput * perpendicular.cosine;
    vy += crossTrackOutput * perpendicular.sine;

    final targetHeading = _rotationTarget(currentPose);
    final rotationOutput = _rotationController.calculate(
      currentPose.rotation.radians.toDouble(),
      targetHeading.radians.toDouble(),
    );

    return ChassisSpeeds.fromFieldRelativeSpeeds(
      ChassisSpeeds(vx: vx, vy: vy, omega: rotationOutput),
      currentPose.rotation,
    );
  }

  void _advanceTargetIfNeeded(Pose2d currentPose) {
    if (_targetWaypointIndex >= waypoints.length - 1) {
      return;
    }

    final target = waypoints[_targetWaypointIndex];
    final segmentLength = _segmentStart.getDistance(target.position).toDouble();
    final progress = _calculateSegmentProgress(
      _segmentStart,
      target.position,
      currentPose.translation,
    );
    final handoffThreshold = segmentLength >= 1e-6
        ? (1.0 - target.handoffDistance / segmentLength).clamp(0.0, 1.0)
        : 1.0;
    final closeEnough = target.position.getDistance(currentPose.translation) <=
        target.handoffDistance;

    if ((segmentLength >= 1e-6 && progress > handoffThreshold) || closeEnough) {
      _targetWaypointIndex++;
      _segmentStart = _segmentEnd;
      _segmentEnd = waypoints[_targetWaypointIndex].position;
      _updateHeldHeading(currentPose.rotation);
    }
  }

  Rotation2d _rotationTarget(Pose2d currentPose) {
    for (var i = _targetWaypointIndex; i < waypoints.length; i++) {
      final rotation = waypoints[i].rotation;
      if (rotation != null) {
        return rotation;
      }
    }
    return _heldHeading ??= currentPose.rotation;
  }

  void _updateHeldHeading(Rotation2d currentHeading) {
    final hasFuturePose = waypoints
        .skip(_targetWaypointIndex)
        .any((waypoint) => waypoint.rotation != null);
    _heldHeading = hasFuturePose ? null : currentHeading;
  }

  static _TrapezoidConstraints _trapezoidConstraints(
    Path2SimulationConstraints constraints,
  ) {
    return _TrapezoidConstraints(
      constraints.maxAngularVelocityRadiansPerSecond,
      constraints.maxAngularAccelerationRadiansPerSecondSquared,
    );
  }

  double _calculateRemainingPathDistance(Pose2d currentPose) {
    var currentPosition = currentPose.translation;
    var remainingDistance = 0.0;
    for (var i = _targetWaypointIndex; i < waypoints.length; i++) {
      remainingDistance +=
          currentPosition.getDistance(waypoints[i].position).toDouble();
      currentPosition = waypoints[i].position;
    }
    return remainingDistance;
  }

  double _calculateCrossTrackError(Pose2d currentPose) {
    final progress = _calculateSegmentProgress(
      _segmentStart,
      _segmentEnd,
      currentPose.translation,
    );
    final closestPoint = _segmentStart.interpolate(_segmentEnd, progress);
    final pathVectorX = _segmentEnd.x - _segmentStart.x;
    final pathVectorY = _segmentEnd.y - _segmentStart.y;
    final robotVectorX = currentPose.x - _segmentStart.x;
    final robotVectorY = currentPose.y - _segmentStart.y;
    final crossProduct =
        pathVectorX * robotVectorY - pathVectorY * robotVectorX;

    var signedError =
        currentPose.translation.getDistance(closestPoint).toDouble();
    if (crossProduct < 0) {
      signedError = -signedError;
    }
    return signedError;
  }

  static double _calculateSegmentProgress(
    Translation2d segmentStart,
    Translation2d segmentEnd,
    Translation2d point,
  ) {
    final dx = segmentEnd.x - segmentStart.x;
    final dy = segmentEnd.y - segmentStart.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < 1e-6) {
      return 0.0;
    }
    final pointDx = point.x - segmentStart.x;
    final pointDy = point.y - segmentStart.y;
    return ((pointDx * dx + pointDy * dy) / lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

class _PidController {
  final double proportionalGain;
  final double period;

  double _positionTolerance = 0.05;
  double _velocityTolerance = double.infinity;
  double _positionError = 0.0;
  double _velocityError = 0.0;
  double _previousError = 0.0;
  bool _hasMeasurement = false;
  bool _continuous = false;
  double _minimumInput = 0.0;
  double _maximumInput = 0.0;

  _PidController(this.proportionalGain, this.period);

  void setTolerance(double positionTolerance,
      [double velocityTolerance = double.infinity]) {
    _positionTolerance = positionTolerance;
    _velocityTolerance = velocityTolerance;
  }

  void enableContinuousInput(double minimumInput, double maximumInput) {
    _continuous = true;
    _minimumInput = minimumInput;
    _maximumInput = maximumInput;
  }

  void reset() {
    _positionError = 0.0;
    _velocityError = 0.0;
    _previousError = 0.0;
    _hasMeasurement = false;
  }

  double calculate(double measurement, double setpoint) {
    _positionError = setpoint - measurement;
    if (_continuous) {
      final errorBound = (_maximumInput - _minimumInput) / 2.0;
      _positionError = _inputModulus(
        _positionError,
        -errorBound,
        errorBound,
      );
    }
    _velocityError =
        _hasMeasurement ? (_positionError - _previousError) / period : 0.0;
    _previousError = _positionError;
    _hasMeasurement = true;
    return proportionalGain * _positionError;
  }

  bool get atSetpoint =>
      _hasMeasurement &&
      _positionError.abs() < _positionTolerance &&
      _velocityError.abs() < _velocityTolerance;
}

class _ProfiledPidController {
  final _PidController _controller;
  final double period;
  _TrapezoidConstraints _constraints;
  _TrapezoidState _setpoint = const _TrapezoidState(0.0, 0.0);
  bool _continuous = false;
  double _minimumInput = 0.0;
  double _maximumInput = 0.0;

  _ProfiledPidController(
    double proportionalGain,
    this.period,
    this._constraints,
  ) : _controller = _PidController(proportionalGain, period);

  void enableContinuousInput(double minimumInput, double maximumInput) {
    _continuous = true;
    _minimumInput = minimumInput;
    _maximumInput = maximumInput;
  }

  void setConstraints(_TrapezoidConstraints constraints) {
    _constraints = constraints;
  }

  void setTolerance(double positionTolerance,
      [double velocityTolerance = double.infinity]) {
    _controller.setTolerance(positionTolerance, velocityTolerance);
  }

  void reset(double measurement, double velocity) {
    _setpoint = _TrapezoidState(measurement, velocity);
    _controller.reset();
  }

  double calculate(double measurement, double goalPosition) {
    var goal = _TrapezoidState(goalPosition, 0.0);
    if (_continuous) {
      final errorBound = (_maximumInput - _minimumInput) / 2.0;
      goal = _TrapezoidState(
        _inputModulus(goal.position - measurement, -errorBound, errorBound) +
            measurement,
        goal.velocity,
      );
      _setpoint = _TrapezoidState(
        _inputModulus(
                _setpoint.position - measurement, -errorBound, errorBound) +
            measurement,
        _setpoint.velocity,
      );
    }

    _setpoint =
        _TrapezoidProfile(_constraints).calculate(period, _setpoint, goal);
    return _controller.calculate(measurement, _setpoint.position);
  }

  bool get atSetpoint => _controller.atSetpoint;
}

class _TrapezoidConstraints {
  final double maxVelocity;
  final double maxAcceleration;

  const _TrapezoidConstraints(this.maxVelocity, this.maxAcceleration);
}

class _TrapezoidState {
  final double position;
  final double velocity;

  const _TrapezoidState(this.position, this.velocity);
}

/// The same analytic trapezoid step used by WPILib's `TrapezoidProfile`.
class _TrapezoidProfile {
  final _TrapezoidConstraints constraints;

  const _TrapezoidProfile(this.constraints);

  _TrapezoidState calculate(
    double time,
    _TrapezoidState current,
    _TrapezoidState goal,
  ) {
    final direction = current.position > goal.position ? -1.0 : 1.0;
    current = _direct(current, direction);
    goal = _direct(goal, direction);

    final currentVelocity = current.velocity
        .clamp(-constraints.maxVelocity, constraints.maxVelocity);
    current = _TrapezoidState(current.position, currentVelocity.toDouble());

    final cutoffBegin = current.velocity / constraints.maxAcceleration;
    final cutoffDistanceBegin =
        cutoffBegin * cutoffBegin * constraints.maxAcceleration / 2.0;
    final cutoffEnd = goal.velocity / constraints.maxAcceleration;
    final cutoffDistanceEnd =
        cutoffEnd * cutoffEnd * constraints.maxAcceleration / 2.0;

    final fullTrapezoidDistance = cutoffDistanceBegin +
        (goal.position - current.position) +
        cutoffDistanceEnd;
    var accelerationTime =
        constraints.maxVelocity / constraints.maxAcceleration;
    var fullSpeedDistance = fullTrapezoidDistance -
        accelerationTime * accelerationTime * constraints.maxAcceleration;
    if (fullSpeedDistance < 0.0) {
      accelerationTime = math.sqrt(
          math.max(0.0, fullTrapezoidDistance) / constraints.maxAcceleration);
      fullSpeedDistance = 0.0;
    }

    final endAcceleration = accelerationTime - cutoffBegin;
    final endFullSpeed =
        endAcceleration + fullSpeedDistance / constraints.maxVelocity;
    final endDeceleration = endFullSpeed + accelerationTime - cutoffEnd;

    late _TrapezoidState result;
    if (time < endAcceleration) {
      final velocity = current.velocity + time * constraints.maxAcceleration;
      result = _TrapezoidState(
        current.position +
            (current.velocity + time * constraints.maxAcceleration / 2.0) *
                time,
        velocity,
      );
    } else if (time < endFullSpeed) {
      result = _TrapezoidState(
        current.position +
            (current.velocity + constraints.maxVelocity) /
                2.0 *
                endAcceleration +
            constraints.maxVelocity * (time - endAcceleration),
        constraints.maxVelocity,
      );
    } else if (time <= endDeceleration) {
      final timeLeft = endDeceleration - time;
      final velocity = goal.velocity + timeLeft * constraints.maxAcceleration;
      result = _TrapezoidState(
        goal.position - (goal.velocity + velocity) / 2.0 * timeLeft,
        velocity,
      );
    } else {
      result = goal;
    }

    return _direct(result, direction);
  }

  static _TrapezoidState _direct(_TrapezoidState state, double direction) =>
      _TrapezoidState(
        state.position * direction,
        state.velocity * direction,
      );
}

double _inputModulus(double input, double minimumInput, double maximumInput) {
  final modulus = maximumInput - minimumInput;
  final numMax = ((input - minimumInput) / modulus).truncate();
  input -= numMax * modulus;
  final numMin = ((input - maximumInput) / modulus).truncate();
  input -= numMin * modulus;
  return input;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
