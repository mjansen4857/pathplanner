import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

void main() {
  group('ChassisSpeeds', () {
    test('constructor and properties', () {
      var speeds = const ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
      expect(speeds.vx, equals(1.0));
      expect(speeds.vy, equals(2.0));
      expect(speeds.omega, equals(3.0));
    });

    test('== operator and hashCode', () {
      var speeds1 = const ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
      var speeds2 = const ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
      var speeds3 = const ChassisSpeeds(vx: 2.0, vy: 3.0, omega: 4.0);
      expect(speeds1, equals(speeds2));
      expect(speeds1.hashCode, equals(speeds2.hashCode));
      expect(speeds1, isNot(equals(speeds3)));
    });

    test('toString', () {
      var speeds = const ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
      expect(speeds.toString(),
          equals('ChassisSpeeds(vx: 1.00, vy: 2.00, omega: 3.00)'));
    });

    test('fromFieldRelativeSpeeds', () {
      var speeds = const ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
      var robotAngle = Rotation2d.fromDegrees(90);
      var result = ChassisSpeeds.fromFieldRelativeSpeeds(speeds, robotAngle);
      expect(result.vx, closeTo(2.0, 0.01));
      expect(result.vy, closeTo(-1.0, 0.01));
      expect(result.omega, equals(3.0));
    });

    test('fromRobotRelativeSpeeds', () {
      var speeds = const ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
      var robotAngle = Rotation2d.fromDegrees(90);
      var result = ChassisSpeeds.fromRobotRelativeSpeeds(speeds, robotAngle);
      expect(result.vx, closeTo(-2.0, 0.01));
      expect(result.vy, closeTo(1.0, 0.01));
      expect(result.omega, equals(3.0));
    });
  });

  group('SwerveDriveKinematics', () {
    test('constructor', () {
      const modules = [
        Translation2d(0.4, 0.4),
        Translation2d(0.4, -0.4),
        Translation2d(-0.4, 0.4),
        Translation2d(-0.4, -0.4),
      ];
      var kinematics = SwerveDriveKinematics(modules);
      expect(kinematics.toSwerveModuleStates(const ChassisSpeeds()).length,
          equals(4));
    });

    test('toSwerveModuleStates', () {
      const modules = [
        Translation2d(0.4, 0.4),
        Translation2d(0.4, -0.4),
        Translation2d(-0.4, 0.4),
        Translation2d(-0.4, -0.4),
      ];
      var kinematics = SwerveDriveKinematics(modules);
      var chassisSpeeds = const ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
      var moduleStates = kinematics.toSwerveModuleStates(chassisSpeeds);
      expect(moduleStates.length, equals(4));
      expect(moduleStates[0].speedMetersPerSecond, closeTo(3.21, 0.01));
      expect(moduleStates[0].angle.degrees, closeTo(93.58, 0.01));
      expect(moduleStates[1].speedMetersPerSecond, closeTo(3.88, 0.01));
      expect(moduleStates[1].angle.degrees, closeTo(55.49, 0.01));
      expect(moduleStates[2].speedMetersPerSecond, closeTo(0.82, 0.01));
      expect(moduleStates[2].angle.degrees, closeTo(104.04, 0.01));
      expect(moduleStates[3].speedMetersPerSecond, closeTo(2.34, 0.01));
      expect(moduleStates[3].angle.degrees, closeTo(19.98, 0.01));
    });

    test('toChassisSpeeds', () {
      const modules = [
        Translation2d(0.4, 0.4),
        Translation2d(0.4, -0.4),
        Translation2d(-0.4, 0.4),
        Translation2d(-0.4, -0.4),
      ];
      var kinematics = SwerveDriveKinematics(modules);
      var moduleStates = [
        SwerveModuleState(),
        SwerveModuleState(),
        SwerveModuleState(),
        SwerveModuleState(),
      ];
      moduleStates[0].speedMetersPerSecond = 3.21;
      moduleStates[0].angle = Rotation2d.fromDegrees(93.58);
      moduleStates[1].speedMetersPerSecond = 3.88;
      moduleStates[1].angle = Rotation2d.fromDegrees(55.49);
      moduleStates[2].speedMetersPerSecond = 0.82;
      moduleStates[2].angle = Rotation2d.fromDegrees(104.04);
      moduleStates[3].speedMetersPerSecond = 2.34;
      moduleStates[3].angle = Rotation2d.fromDegrees(19.98);
      var chassisSpeeds = kinematics.toChassisSpeeds(moduleStates);
      expect(chassisSpeeds.vx, closeTo(1.0, 0.01));
      expect(chassisSpeeds.vy, closeTo(2.0, 0.01));
      expect(chassisSpeeds.omega, closeTo(3.0, 0.01));
    });
  });
}
