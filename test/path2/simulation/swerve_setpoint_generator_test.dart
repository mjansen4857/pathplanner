import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/simulation/swerve_module_state.dart';
import 'package:pathplanner/path2/simulation/swerve_setpoint_generator.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

void main() {
  group('SwerveSetpointGenerator', () {
    late Path2RobotConfigSnapshot config;
    late SwerveSetpointGenerator generator;

    setUp(() {
      config = _testConfig();
      generator = SwerveSetpointGenerator(config);
    });

    test('uses the fixed simulator operating conditions', () {
      expect(SwerveSetpointGenerator.periodSeconds, 0.02);
      expect(SwerveSetpointGenerator.inputVoltage, 12.0);
      expect(
        SwerveSetpointGenerator.maxSteerVelocityRadiansPerSecond,
        closeTo(20.0 * math.pi, 1e-12),
      );
    });

    test('complete stop retains every previous steering angle', () {
      final previous = Path2SwerveSetpoint(
        robotRelativeSpeeds: const ChassisSpeeds(),
        moduleStates: [15.0, -40.0, 95.0, 179.0]
            .map(
              (degrees) => Path2SimulationModuleState(
                angle: Rotation2d.fromDegrees(degrees),
              ),
            )
            .toList(),
      );

      final next = generator.generateSetpoint(previous, const ChassisSpeeds());

      expect(next.robotRelativeSpeeds, const ChassisSpeeds());
      for (var module = 0; module < 4; module++) {
        expect(next.moduleStates[module].speedMetersPerSecond, 0.0);
        expect(
          next.moduleStates[module].angle,
          previous.moduleStates[module].angle,
        );
      }
    });

    test('stationary modules turn at most 72 degrees per 20 ms step', () {
      final next = generator.generateSetpoint(
        Path2SwerveSetpoint.atRest(),
        const ChassisSpeeds(vy: 2.0),
      );

      expect(next.robotRelativeSpeeds.linearVel, closeTo(0.0, 1e-12));
      for (final state in next.moduleStates) {
        expect(state.speedMetersPerSecond, closeTo(0.0, 1e-12));
        expect(state.angle.degrees, closeTo(72.0, 1e-9));
      }
    });

    test('wheel friction limits first-step forward acceleration', () {
      final frictionLimitedConfig = _testConfig(currentLimitAmps: 500.0);
      final frictionLimitedGenerator = SwerveSetpointGenerator(
        frictionLimitedConfig,
      );
      final next = frictionLimitedGenerator.generateSetpoint(
        Path2SwerveSetpoint.atRest(),
        const ChassisSpeeds(vx: 20.0),
      );
      final maximumVelocityStep =
          frictionLimitedConfig.wheelCoefficientOfFriction *
          9.8 *
          SwerveSetpointGenerator.periodSeconds;

      expect(next.robotRelativeSpeeds.vx, greaterThan(0.0));
      expect(next.robotRelativeSpeeds.vx, closeTo(maximumVelocityStep, 1e-9));
      expect(next.robotRelativeSpeeds.vy, closeTo(0.0, 1e-12));
      expect(next.robotRelativeSpeeds.omega, closeTo(0.0, 1e-12));
      for (final state in next.moduleStates) {
        expect(state.speedMetersPerSecond, closeTo(maximumVelocityStep, 1e-9));
      }
    });

    test('drive current limit can be the active acceleration constraint', () {
      final currentLimitedConfig = _testConfig(
        currentLimitAmps: 5.0,
        coefficientOfFriction: 10.0,
      );
      final currentLimitedGenerator = SwerveSetpointGenerator(
        currentLimitedConfig,
      );

      final next = currentLimitedGenerator.generateSetpoint(
        Path2SwerveSetpoint.atRest(),
        const ChassisSpeeds(vx: 4.0),
      );
      final expectedModuleTorque =
          currentLimitedConfig.motorTorque(5.0) -
          currentLimitedConfig.torqueLoss;
      final expectedAcceleration =
          (expectedModuleTorque / currentLimitedConfig.wheelRadiusMeters * 4) /
          currentLimitedConfig.massKg;

      expect(
        next.robotRelativeSpeeds.vx,
        closeTo(
          expectedAcceleration * SwerveSetpointGenerator.periodSeconds,
          1e-9,
        ),
      );
    });

    test('opposite nonzero request decelerates before flipping modules', () {
      final previous = Path2SwerveSetpoint(
        robotRelativeSpeeds: const ChassisSpeeds(vx: 1.0),
        moduleStates: List.filled(
          4,
          const Path2SimulationModuleState(speedMetersPerSecond: 1.0),
        ),
      );

      final next = generator.generateSetpoint(
        previous,
        const ChassisSpeeds(vx: -1.0),
      );

      expect(next.robotRelativeSpeeds.vx, inExclusiveRange(0.0, 1.0));
      for (final state in next.moduleStates) {
        expect(state.speedMetersPerSecond, greaterThan(0.0));
        expect(state.angle.radians, closeTo(0.0, 1e-12));
      }
    });

    test('setpoint map serialization preserves carried physical state', () {
      final original = generator.generateSetpoint(
        Path2SwerveSetpoint.atRest(),
        const ChassisSpeeds(vx: 1.0, vy: 0.2, omega: 0.5),
      );

      final restored = Path2SwerveSetpoint.fromMap(original.toMap());

      expect(restored.robotRelativeSpeeds, original.robotRelativeSpeeds);
      expect(restored.moduleStates, original.moduleStates);
    });
  });
}

Path2RobotConfigSnapshot _testConfig({
  double currentLimitAmps = 60.0,
  double coefficientOfFriction = 1.2,
}) {
  return Path2RobotConfigSnapshot(
    massKg: 50.0,
    momentOfInertiaKgMetersSquared: 6.0,
    wheelRadiusMeters: 0.05,
    maxDriveVelocityMetersPerSecond: 4.5,
    driveCurrentLimitAmps: currentLimitAmps,
    wheelCoefficientOfFriction: coefficientOfFriction,
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
