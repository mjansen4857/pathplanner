import 'package:matrices/matrices.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:scidart/numdart.dart';

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

  @override
  String toString() {
    return 'ChassisSpeeds(vx: ${vx.toStringAsFixed(2)}, vy: ${vy.toStringAsFixed(2)}, omega: ${omega.toStringAsFixed(2)})';
  }

  factory ChassisSpeeds.fromFieldRelativeSpeeds(
      ChassisSpeeds speeds, Rotation2d robotAngle) {
    Translation2d rotated =
        Translation2d(speeds.vx, speeds.vy).rotateBy(-robotAngle);
    return ChassisSpeeds(vx: rotated.x, vy: rotated.y, omega: speeds.omega);
  }

  factory ChassisSpeeds.fromRobotRelativeSpeeds(
      ChassisSpeeds speeds, Rotation2d robotAngle) {
    Translation2d rotated =
        Translation2d(speeds.vx, speeds.vy).rotateBy(robotAngle);
    return ChassisSpeeds(vx: rotated.x, vy: rotated.y, omega: speeds.omega);
  }
}

class SwerveModuleState {
  num speedMetersPerSecond = 0.0;
  Rotation2d angle = const Rotation2d();
}

class SwerveDriveKinematics {
  int _numModules = 4;
  List<Translation2d> _modules = [];
  List<Rotation2d> _moduleHeadings = [];
  Translation2d _prevCoR = const Translation2d();

  Matrix _inverseKinematics = Matrix();
  Matrix _forwardKinematics = Matrix();

  SwerveDriveKinematics(List<Translation2d> modules) {
    _numModules = modules.length;
    _modules = List.of(modules);
    _moduleHeadings = List.generate(_numModules, (i) => const Rotation2d());
    _inverseKinematics = Matrix.zero(_numModules * 2, 3);
    _forwardKinematics = Matrix.zero(3, _numModules * 2);

    for (int i = 0; i < _numModules; i++) {
      _inverseKinematics.setRow([1, 0, -_modules[i].y.toDouble()], i * 2);
      _inverseKinematics.setRow([0, 1, _modules[i].x.toDouble()], i * 2 + 1);
    }

    Array2d inverse = Array2d.fixed(_numModules * 2, 3);
    for (int i = 0; i < _inverseKinematics.rowCount; i++) {
      inverse[i] = Array(_inverseKinematics.row(i));
    }
    Array2d forward = matrixPseudoInverse(inverse);

    for (int i = 0; i < _forwardKinematics.rowCount; i++) {
      _forwardKinematics.setRow(forward[i], i);
    }
  }

  List<SwerveModuleState> toSwerveModuleStates(ChassisSpeeds chassisSpeeds,
      {Translation2d centerOfRotationMeters = const Translation2d()}) {
    var moduleStates =
        List.generate(_numModules, (index) => SwerveModuleState());

    if (chassisSpeeds.vx == 0 &&
        chassisSpeeds.vy == 0 &&
        chassisSpeeds.omega == 0) {
      for (int i = 0; i < _numModules; i++) {
        moduleStates[i].angle = _moduleHeadings[i];
      }

      return moduleStates;
    }

    if (centerOfRotationMeters != _prevCoR) {
      for (int i = 0; i < _numModules; i++) {
        _inverseKinematics.setRow(
            [1, 0, -_modules[i].y.toDouble() + centerOfRotationMeters.y],
            i * 2);
        _inverseKinematics.setRow(
            [0, 1, _modules[i].x.toDouble() - centerOfRotationMeters.x],
            i * 2 + 1);
      }
      _prevCoR = centerOfRotationMeters;
    }

    var chassisSpeedsVector = Matrix.zero(3, 1);
    chassisSpeedsVector.setColumn([
      chassisSpeeds.vx.toDouble(),
      chassisSpeeds.vy.toDouble(),
      chassisSpeeds.omega.toDouble()
    ], 0);

    var moduleStatesMatrix = _inverseKinematics * chassisSpeedsVector;

    for (int i = 0; i < _numModules; i++) {
      num x = moduleStatesMatrix.row(i * 2)[0];
      num y = moduleStatesMatrix.row(i * 2 + 1)[0];

      num speed = sqrt(pow(x, 2) + pow(y, 2));
      Rotation2d angle = Rotation2d.fromComponents(x, y);

      moduleStates[i].speedMetersPerSecond = speed;
      moduleStates[i].angle = angle;
    }

    return moduleStates;
  }

  ChassisSpeeds toChassisSpeeds(List<SwerveModuleState> moduleStates) {
    if (moduleStates.length != _numModules) {
      throw ArgumentError(
          'Number of modules is not consistent with number of module locations');
    }

    var moduleStatesMatrix = Matrix.zero(_numModules * 2, 1);

    for (int i = 0; i < _numModules; i++) {
      moduleStatesMatrix.setRow([
        moduleStates[i].speedMetersPerSecond.toDouble() *
            moduleStates[i].angle.cosine
      ], i * 2);
      moduleStatesMatrix.setRow([
        moduleStates[i].speedMetersPerSecond.toDouble() *
            moduleStates[i].angle.sine
      ], i * 2 + 1);
    }

    var chassisSpeedsVector = _forwardKinematics * moduleStatesMatrix;
    return ChassisSpeeds(
      vx: chassisSpeedsVector.row(0)[0],
      vy: chassisSpeedsVector.row(1)[0],
      omega: chassisSpeedsVector.row(2)[0],
    );
  }
}
