import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/simulation/swerve_math.dart';
import 'package:pathplanner/path2/simulation/swerve_module_state.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

void main() {
  group('Path2SimulationModuleState', () {
    test(
      'optimization reverses speed when steering travel exceeds 90 degrees',
      () {
        final state = Path2SimulationModuleState(
          speedMetersPerSecond: 2.0,
          angle: Rotation2d.fromDegrees(170),
        );

        final optimized = state.optimized(const Rotation2d());

        expect(optimized.speedMetersPerSecond, -2.0);
        expect(optimized.angle.degrees, closeTo(-10.0, 1e-9));
      },
    );

    test('optimization leaves a 90 degree change alone', () {
      final state = Path2SimulationModuleState(
        speedMetersPerSecond: 2.0,
        angle: Rotation2d.fromDegrees(90),
      );

      expect(state.optimized(const Rotation2d()), same(state));
    });
  });

  group('Path2SimulationMath', () {
    test('desaturates every wheel by the same scale', () {
      final states = [
        const Path2SimulationModuleState(speedMetersPerSecond: 5.0),
        const Path2SimulationModuleState(speedMetersPerSecond: -4.0),
        const Path2SimulationModuleState(speedMetersPerSecond: 2.5),
        const Path2SimulationModuleState(speedMetersPerSecond: 0.0),
      ];

      final result = Path2SimulationMath.desaturateWheelSpeeds(states, 4.0);

      expect(result[0].speedMetersPerSecond, 4.0);
      expect(result[1].speedMetersPerSecond, -3.2);
      expect(result[2].speedMetersPerSecond, 2.0);
      expect(result[3].speedMetersPerSecond, 0.0);
    });

    test('discretize and pose exponential preserve the desired delta pose', () {
      const dt = 0.02;
      const requested = ChassisSpeeds(vx: 1.0, vy: 0.0, omega: 1.0);

      final discretized = Path2SimulationMath.discretizeChassisSpeeds(
        requested,
        dt,
      );
      final integrated = Path2SimulationMath.integratePose(
        const Pose2d(Translation2d(), Rotation2d()),
        discretized,
        dt,
      );

      expect(discretized.vx, closeTo(0.9999666664, 1e-9));
      expect(discretized.vy, closeTo(-0.01, 1e-9));
      expect(discretized.omega, closeTo(1.0, 1e-12));
      expect(integrated.x, closeTo(0.02, 1e-12));
      expect(integrated.y, closeTo(0.0, 1e-12));
      expect(integrated.rotation.radians, closeTo(0.02, 1e-12));
    });

    test('pose logarithm and exponential round trip', () {
      final start = Pose2d(
        const Translation2d(1.2, -0.7),
        Rotation2d.fromDegrees(38),
      );
      const twist = Path2Twist2d(dx: 2.0, dy: -0.4, dtheta: 1.3);

      final end = Path2SimulationMath.poseExp(start, twist);
      final recovered = Path2SimulationMath.poseLog(start, end);

      expect(recovered.dx, closeTo(twist.dx, 1e-9));
      expect(recovered.dy, closeTo(twist.dy, 1e-9));
      expect(recovered.dtheta, closeTo(twist.dtheta, 1e-9));
    });
  });

  group('Path2SimulationResult', () {
    Path2SimulationState stateAt(double x, double heading) {
      return Path2SimulationState(
        pose: Pose2d(Translation2d(x, 0), Rotation2d.fromRadians(heading)),
        robotRelativeSpeeds: ChassisSpeeds(vx: x),
        moduleStates: List.generate(
          4,
          (_) => Path2SimulationModuleState(
            speedMetersPerSecond: x,
            angle: Rotation2d.fromRadians(heading),
          ),
        ),
      );
    }

    test('sampleAt interpolates animation state and clamps endpoints', () {
      final result = Path2SimulationResult([
        Path2SimulationSample(timeSeconds: 0.0, state: stateAt(0.0, 0.0)),
        Path2SimulationSample(
          timeSeconds: 0.02,
          state: stateAt(2.0, math.pi / 2.0),
        ),
      ]);

      final halfway = result.sampleAt(0.01);

      expect(halfway.timeSeconds, 0.01);
      expect(halfway.pose.x, closeTo(1.0, 1e-12));
      expect(halfway.pose.rotation.radians, closeTo(math.pi / 4.0, 1e-12));
      expect(halfway.robotRelativeSpeeds.vx, closeTo(1.0, 1e-12));
      expect(halfway.moduleStates.first.speedMetersPerSecond, 1.0);
      expect(result.sampleAt(-1.0), same(result.samples.first));
      expect(result.sampleAt(4.0), same(result.samples.last));
    });

    test('map serialization round trips state and config primitives', () {
      final config = _testConfig();
      final restoredConfig = Path2RobotConfigSnapshot.fromMap(config.toMap());
      final result = Path2SimulationResult(
        [Path2SimulationSample(timeSeconds: 0.0, state: stateAt(1.0, 0.2))],
        markerActivations: const [
          Path2SimulationMarkerActivation(
            pathIndex: 2,
            markerIndex: 3,
            startTimeSeconds: 0,
            endTimeSeconds: 0,
          ),
        ],
      );
      final restoredResult = Path2SimulationResult.fromMap(result.toMap());

      expect(restoredConfig.massKg, config.massKg);
      expect(restoredConfig.moduleLocations, config.moduleLocations);
      expect(restoredConfig.torqueLoss, closeTo(config.torqueLoss, 1e-12));
      expect(restoredResult.terminalState.pose.x, 1.0);
      expect(restoredResult.terminalState.moduleStates.length, 4);
      expect(restoredResult.markerActivations.single.pathIndex, 2);
      expect(restoredResult.markerActivations.single.markerIndex, 3);
      expect(restoredResult.markerActivations.single.endTimeSeconds, 0);
    });
  });
}

Path2RobotConfigSnapshot _testConfig() {
  return Path2RobotConfigSnapshot(
    massKg: 50.0,
    momentOfInertiaKgMetersSquared: 6.0,
    wheelRadiusMeters: 0.05,
    maxDriveVelocityMetersPerSecond: 4.5,
    driveCurrentLimitAmps: 60.0,
    wheelCoefficientOfFriction: 1.2,
    motorNominalVoltage: 12.0,
    motorStallTorqueNewtonMeters: 7.09 * 6.75,
    motorStallCurrentAmps: 366.0,
    motorFreeCurrentAmps: 2.0,
    motorFreeSpeedRadiansPerSecond: 6000.0 * 2.0 * math.pi / 60.0 / 6.75,
    moduleLocations: const [
      Translation2d(0.3, 0.3),
      Translation2d(0.3, -0.3),
      Translation2d(-0.3, 0.3),
      Translation2d(-0.3, -0.3),
    ],
  );
}
