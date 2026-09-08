import 'dart:math' as math;

import 'package:pathplanner/path2/simulation/swerve_module_state.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

/// A primitive-only snapshot of the robot properties used by Path2 simulation.
///
/// Keeping this separate from [RobotConfig] avoids carrying Flutter objects or
/// mutable kinematics state across an isolate boundary.
class Path2RobotConfigSnapshot {
  final double massKg;
  final double momentOfInertiaKgMetersSquared;
  final double wheelRadiusMeters;
  final double maxDriveVelocityMetersPerSecond;
  final double driveCurrentLimitAmps;
  final double wheelCoefficientOfFriction;
  final double motorNominalVoltage;
  final double motorStallTorqueNewtonMeters;
  final double motorStallCurrentAmps;
  final double motorFreeCurrentAmps;
  final double motorFreeSpeedRadiansPerSecond;
  final List<Translation2d> moduleLocations;

  Path2RobotConfigSnapshot({
    required this.massKg,
    required this.momentOfInertiaKgMetersSquared,
    required this.wheelRadiusMeters,
    required this.maxDriveVelocityMetersPerSecond,
    required this.driveCurrentLimitAmps,
    required this.wheelCoefficientOfFriction,
    required this.motorNominalVoltage,
    required this.motorStallTorqueNewtonMeters,
    required this.motorStallCurrentAmps,
    required this.motorFreeCurrentAmps,
    required this.motorFreeSpeedRadiansPerSecond,
    required List<Translation2d> moduleLocations,
  }) : moduleLocations = List.unmodifiable(moduleLocations) {
    _validate();
  }

  factory Path2RobotConfigSnapshot.fromRobotConfig(RobotConfig config) {
    final motor = config.moduleConfig.driveMotor;
    return Path2RobotConfigSnapshot(
      massKg: config.massKG.toDouble(),
      momentOfInertiaKgMetersSquared: config.moi.toDouble(),
      wheelRadiusMeters: config.moduleConfig.wheelRadiusMeters.toDouble(),
      maxDriveVelocityMetersPerSecond: config.moduleConfig.maxDriveVelocityMPS
          .toDouble(),
      driveCurrentLimitAmps: config.moduleConfig.driveCurrentLimit.toDouble(),
      wheelCoefficientOfFriction: config.moduleConfig.wheelCOF.toDouble(),
      motorNominalVoltage: motor.nominalVoltageVolts.toDouble(),
      motorStallTorqueNewtonMeters: motor.stallTorqueNM.toDouble(),
      motorStallCurrentAmps: motor.stallCurrentAmps.toDouble(),
      motorFreeCurrentAmps: motor.freeCurrentAmps.toDouble(),
      motorFreeSpeedRadiansPerSecond: motor.freeSpeedRadPerSec.toDouble(),
      moduleLocations: config.moduleLocations,
    );
  }

  factory Path2RobotConfigSnapshot.fromMap(Map<String, dynamic> map) {
    return Path2RobotConfigSnapshot(
      massKg: (map['massKg'] as num).toDouble(),
      momentOfInertiaKgMetersSquared:
          (map['momentOfInertiaKgMetersSquared'] as num).toDouble(),
      wheelRadiusMeters: (map['wheelRadiusMeters'] as num).toDouble(),
      maxDriveVelocityMetersPerSecond:
          (map['maxDriveVelocityMetersPerSecond'] as num).toDouble(),
      driveCurrentLimitAmps: (map['driveCurrentLimitAmps'] as num).toDouble(),
      wheelCoefficientOfFriction: (map['wheelCoefficientOfFriction'] as num)
          .toDouble(),
      motorNominalVoltage: (map['motorNominalVoltage'] as num).toDouble(),
      motorStallTorqueNewtonMeters: (map['motorStallTorqueNewtonMeters'] as num)
          .toDouble(),
      motorStallCurrentAmps: (map['motorStallCurrentAmps'] as num).toDouble(),
      motorFreeCurrentAmps: (map['motorFreeCurrentAmps'] as num).toDouble(),
      motorFreeSpeedRadiansPerSecond:
          (map['motorFreeSpeedRadiansPerSecond'] as num).toDouble(),
      moduleLocations: (map['moduleLocations'] as List<dynamic>)
          .map(
            (location) => Translation2d.fromJson(
              Map<String, dynamic>.from(location as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  int get numModules => moduleLocations.length;

  List<double> get modulePivotDistances => moduleLocations
      .map((location) => location.norm.toDouble())
      .toList(growable: false);

  double get wheelFrictionForce =>
      wheelCoefficientOfFriction * ((massKg / numModules) * 9.8);

  double get maxTorqueBeforeWheelSlip => wheelFrictionForce * wheelRadiusMeters;

  double get motorResistanceOhms => motorNominalVoltage / motorStallCurrentAmps;

  double get motorVelocityConstantRadiansPerSecondPerVolt =>
      motorFreeSpeedRadiansPerSecond /
      (motorNominalVoltage - motorResistanceOhms * motorFreeCurrentAmps);

  double get motorTorqueConstantNewtonMetersPerAmp =>
      motorStallTorqueNewtonMeters / motorStallCurrentAmps;

  double get maxDriveVelocityRadiansPerSecond =>
      maxDriveVelocityMetersPerSecond / wheelRadiusMeters;

  double get torqueLoss {
    final current = motorCurrent(maxDriveVelocityRadiansPerSecond, 12.0);
    return math.max(motorTorque(math.min(current, driveCurrentLimitAmps)), 0.0);
  }

  double motorCurrent(double speedRadiansPerSecond, double voltage) {
    return -speedRadiansPerSecond /
            motorVelocityConstantRadiansPerSecondPerVolt /
            motorResistanceOhms +
        voltage / motorResistanceOhms;
  }

  double motorTorque(double currentAmps) =>
      currentAmps * motorTorqueConstantNewtonMetersPerAmp;

  Map<String, dynamic> toMap() => {
    'massKg': massKg,
    'momentOfInertiaKgMetersSquared': momentOfInertiaKgMetersSquared,
    'wheelRadiusMeters': wheelRadiusMeters,
    'maxDriveVelocityMetersPerSecond': maxDriveVelocityMetersPerSecond,
    'driveCurrentLimitAmps': driveCurrentLimitAmps,
    'wheelCoefficientOfFriction': wheelCoefficientOfFriction,
    'motorNominalVoltage': motorNominalVoltage,
    'motorStallTorqueNewtonMeters': motorStallTorqueNewtonMeters,
    'motorStallCurrentAmps': motorStallCurrentAmps,
    'motorFreeCurrentAmps': motorFreeCurrentAmps,
    'motorFreeSpeedRadiansPerSecond': motorFreeSpeedRadiansPerSecond,
    'moduleLocations': moduleLocations
        .map((location) => location.toJson())
        .toList(growable: false),
  };

  void _validate() {
    final positiveValues = <double>[
      massKg,
      momentOfInertiaKgMetersSquared,
      wheelRadiusMeters,
      maxDriveVelocityMetersPerSecond,
      driveCurrentLimitAmps,
      wheelCoefficientOfFriction,
      motorNominalVoltage,
      motorStallTorqueNewtonMeters,
      motorStallCurrentAmps,
      motorFreeSpeedRadiansPerSecond,
    ];
    if (positiveValues.any((value) => !value.isFinite || value <= 0.0)) {
      throw ArgumentError(
        'Path2 robot configuration must be finite and positive',
      );
    }
    if (!motorFreeCurrentAmps.isFinite || motorFreeCurrentAmps < 0.0) {
      throw ArgumentError('Motor free current must be finite and non-negative');
    }
    if (moduleLocations.length != 4 ||
        moduleLocations.any(
          (location) =>
              !location.x.toDouble().isFinite ||
              !location.y.toDouble().isFinite ||
              location.norm <= 0.0,
        )) {
      throw ArgumentError(
        'Path2 simulation requires four valid swerve modules',
      );
    }
    if (!motorVelocityConstantRadiansPerSecondPerVolt.isFinite ||
        motorVelocityConstantRadiansPerSecondPerVolt <= 0.0) {
      throw ArgumentError('Drive motor model has an invalid velocity constant');
    }
  }
}

/// The physical state carried between Path2 path simulations.
class Path2SimulationState {
  final Pose2d pose;
  final ChassisSpeeds robotRelativeSpeeds;
  final List<Path2SimulationModuleState> moduleStates;

  Path2SimulationState({
    required this.pose,
    required this.robotRelativeSpeeds,
    required List<Path2SimulationModuleState> moduleStates,
  }) : moduleStates = List.unmodifiable(moduleStates) {
    if (moduleStates.length != 4) {
      throw ArgumentError('Path2 simulation state requires four modules');
    }
  }

  factory Path2SimulationState.atRest(Pose2d pose) {
    return Path2SimulationState(
      pose: pose,
      robotRelativeSpeeds: const ChassisSpeeds(),
      moduleStates: List.filled(
        4,
        const Path2SimulationModuleState(),
        growable: false,
      ),
    );
  }

  factory Path2SimulationState.fromMap(Map<String, dynamic> map) {
    final poseMap = Map<String, dynamic>.from(map['pose'] as Map);
    final translation = Map<String, dynamic>.from(
      poseMap['translation'] as Map,
    );
    final speeds = Map<String, dynamic>.from(map['robotRelativeSpeeds'] as Map);
    return Path2SimulationState(
      pose: Pose2d(
        Translation2d.fromJson(translation),
        Rotation2d.fromRadians((poseMap['rotationRadians'] as num).toDouble()),
      ),
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

  Path2SimulationState interpolate(Path2SimulationState endValue, double t) {
    if (endValue.moduleStates.length != moduleStates.length) {
      throw ArgumentError('Cannot interpolate states with different modules');
    }
    final clampedT = t.clamp(0.0, 1.0);
    return Path2SimulationState(
      pose: pose.interpolate(endValue.pose, clampedT),
      robotRelativeSpeeds: ChassisSpeeds(
        vx:
            robotRelativeSpeeds.vx +
            (endValue.robotRelativeSpeeds.vx - robotRelativeSpeeds.vx) *
                clampedT,
        vy:
            robotRelativeSpeeds.vy +
            (endValue.robotRelativeSpeeds.vy - robotRelativeSpeeds.vy) *
                clampedT,
        omega:
            robotRelativeSpeeds.omega +
            (endValue.robotRelativeSpeeds.omega - robotRelativeSpeeds.omega) *
                clampedT,
      ),
      moduleStates: List.generate(
        moduleStates.length,
        (index) => moduleStates[index].interpolate(
          endValue.moduleStates[index],
          clampedT,
        ),
        growable: false,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'pose': {
      'translation': pose.translation.toJson(),
      'rotationRadians': pose.rotation.radians.toDouble(),
    },
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

class Path2SimulationSample {
  final double timeSeconds;
  final Path2SimulationState state;

  const Path2SimulationSample({required this.timeSeconds, required this.state});

  factory Path2SimulationSample.fromMap(Map<String, dynamic> map) {
    return Path2SimulationSample(
      timeSeconds: (map['timeSeconds'] as num).toDouble(),
      state: Path2SimulationState.fromMap(
        Map<String, dynamic>.from(map['state'] as Map),
      ),
    );
  }

  Pose2d get pose => state.pose;
  ChassisSpeeds get robotRelativeSpeeds => state.robotRelativeSpeeds;
  List<Path2SimulationModuleState> get moduleStates => state.moduleStates;

  Map<String, dynamic> toMap() => {
    'timeSeconds': timeSeconds,
    'state': state.toMap(),
  };
}

/// The interval in a simulated auto where an event marker is active.
///
/// Point markers have no [endTimeSeconds]. Zoned markers include both their
/// start and end trigger samples so the editor can highlight the exact portion
/// of the simulated trace.
class Path2SimulationMarkerActivation {
  final int pathIndex;
  final int markerIndex;
  final double startTimeSeconds;
  final double? endTimeSeconds;

  const Path2SimulationMarkerActivation({
    required this.pathIndex,
    required this.markerIndex,
    required this.startTimeSeconds,
    this.endTimeSeconds,
  });

  factory Path2SimulationMarkerActivation.fromMap(Map<String, dynamic> map) {
    final endTime = map['endTimeSeconds'];
    return Path2SimulationMarkerActivation(
      pathIndex: (map['pathIndex'] as num).toInt(),
      markerIndex: (map['markerIndex'] as num).toInt(),
      startTimeSeconds: (map['startTimeSeconds'] as num).toDouble(),
      endTimeSeconds: endTime is num ? endTime.toDouble() : null,
    );
  }

  bool get isZoned => endTimeSeconds != null;

  Path2SimulationMarkerActivation shifted({
    required int pathIndex,
    required double timeOffsetSeconds,
  }) {
    return Path2SimulationMarkerActivation(
      pathIndex: pathIndex,
      markerIndex: markerIndex,
      startTimeSeconds: startTimeSeconds + timeOffsetSeconds,
      endTimeSeconds: endTimeSeconds == null
          ? null
          : endTimeSeconds! + timeOffsetSeconds,
    );
  }

  Map<String, dynamic> toMap() => {
    'pathIndex': pathIndex,
    'markerIndex': markerIndex,
    'startTimeSeconds': startTimeSeconds,
    'endTimeSeconds': endTimeSeconds,
  };
}

/// A transient first-match location for one branch event assignment.
class Path2BranchEventMarker {
  final String branchId;
  final int eventIndex;
  final String name;
  final double timeSeconds;
  final Pose2d pose;

  const Path2BranchEventMarker({
    required this.branchId,
    required this.eventIndex,
    required this.name,
    required this.timeSeconds,
    required this.pose,
  });

  factory Path2BranchEventMarker.fromMap(Map<String, dynamic> map) =>
      Path2BranchEventMarker(
        branchId: map['branchId'] as String,
        eventIndex: (map['eventIndex'] as num).toInt(),
        name: map['name'] as String,
        timeSeconds: (map['timeSeconds'] as num).toDouble(),
        pose: Pose2d(
          Translation2d((map['x'] as num), (map['y'] as num)),
          Rotation2d.fromRadians(map['rotation'] as num),
        ),
      );
  Map<String, dynamic> toMap() => {
    'branchId': branchId,
    'eventIndex': eventIndex,
    'name': name,
    'timeSeconds': timeSeconds,
    'x': pose.translation.x,
    'y': pose.translation.y,
    'rotation': pose.rotation.radians,
  };
}

class Path2SimulationResult {
  final List<Path2SimulationSample> samples;
  final List<Path2SimulationMarkerActivation> markerActivations;
  final List<Path2BranchEventMarker> branchEventMarkers;

  Path2SimulationResult(
    List<Path2SimulationSample> samples, {
    List<Path2SimulationMarkerActivation> markerActivations = const [],
    List<Path2BranchEventMarker> branchEventMarkers = const [],
  }) : samples = List.unmodifiable(samples),
       branchEventMarkers = List.unmodifiable(branchEventMarkers),
       markerActivations = List.unmodifiable(markerActivations) {
    if (samples.isEmpty) {
      throw ArgumentError('A simulation result requires at least one sample');
    }
    for (var i = 0; i < samples.length; i++) {
      if (!samples[i].timeSeconds.isFinite || samples[i].timeSeconds < 0.0) {
        throw ArgumentError(
          'Simulation sample times must be finite and non-negative',
        );
      }
      if (i > 0 && samples[i].timeSeconds <= samples[i - 1].timeSeconds) {
        throw ArgumentError(
          'Simulation sample times must be strictly increasing',
        );
      }
    }
    for (final activation in markerActivations) {
      final endTime = activation.endTimeSeconds;
      if (activation.pathIndex < 0 ||
          activation.markerIndex < 0 ||
          !activation.startTimeSeconds.isFinite ||
          activation.startTimeSeconds < 0.0 ||
          activation.startTimeSeconds > samples.last.timeSeconds + 1e-9 ||
          (endTime != null &&
              (!endTime.isFinite ||
                  endTime < activation.startTimeSeconds ||
                  endTime > samples.last.timeSeconds + 1e-9))) {
        throw ArgumentError('Simulation marker activation is invalid');
      }
    }
  }

  factory Path2SimulationResult.fromMap(Map<String, dynamic> map) {
    return Path2SimulationResult(
      (map['samples'] as List<dynamic>)
          .map(
            (sample) => Path2SimulationSample.fromMap(
              Map<String, dynamic>.from(sample as Map),
            ),
          )
          .toList(growable: false),
      branchEventMarkers: (map['branchEventMarkers'] as List? ?? [])
          .map(
            (value) => Path2BranchEventMarker.fromMap(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      markerActivations:
          (map['markerActivations'] as List<dynamic>? ?? const [])
              .map(
                (activation) => Path2SimulationMarkerActivation.fromMap(
                  Map<String, dynamic>.from(activation as Map),
                ),
              )
              .toList(growable: false),
    );
  }

  double get totalTimeSeconds => samples.last.timeSeconds;
  Path2SimulationState get terminalState => samples.last.state;

  /// Samples the simulation at an arbitrary animation time.
  ///
  /// Times outside the result are clamped. Values between the fixed physics
  /// samples are interpolated solely for rendering; they do not affect the
  /// 20 ms simulation.
  Path2SimulationSample sampleAt(double timeSeconds) {
    if (timeSeconds.isNaN || timeSeconds <= samples.first.timeSeconds) {
      return samples.first;
    }
    if (timeSeconds >= samples.last.timeSeconds) {
      return samples.last;
    }

    var low = 0;
    var high = samples.length - 1;
    while (low + 1 < high) {
      final mid = (low + high) ~/ 2;
      if (samples[mid].timeSeconds <= timeSeconds) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final start = samples[low];
    final end = samples[high];
    final t =
        (timeSeconds - start.timeSeconds) /
        (end.timeSeconds - start.timeSeconds);
    return Path2SimulationSample(
      timeSeconds: timeSeconds,
      state: start.state.interpolate(end.state, t),
    );
  }

  Map<String, dynamic> toMap() => {
    'samples': samples.map((sample) => sample.toMap()).toList(growable: false),
    'branchEventMarkers': branchEventMarkers
        .map((marker) => marker.toMap())
        .toList(),
    'markerActivations': markerActivations
        .map((activation) => activation.toMap())
        .toList(growable: false),
  };
}

enum Path2SimulationFailureKind {
  invalidConfiguration,
  invalidPath,
  missingPath,
  nonFiniteState,
  stalled,
  timedOut,
}

class Path2SimulationFailure implements Exception {
  final Path2SimulationFailureKind kind;
  final String message;

  const Path2SimulationFailure(this.kind, this.message);

  @override
  String toString() => 'Path2 simulation failed: $message';
}
