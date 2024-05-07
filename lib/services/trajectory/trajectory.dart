import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';

class TrajectoryState {
  num timeSeconds = 0.0;
  ChassisSpeeds fieldSpeeds = const ChassisSpeeds();
  Pose2d pose = Pose2d(const Translation2d(), Rotation2d());
  Rotation2d heading = Rotation2d();
  num deltaPos = 0.0;
  Rotation2d deltaRot = Rotation2d();

  List<SwerveModuleTrajState> moduleStates = [];

  TrajectoryState interpolate(TrajectoryState endVal, num t) {
    TrajectoryState lerpedState = TrajectoryState();

    lerpedState.timeSeconds =
        MathUtil.interpolate(timeSeconds, endVal.timeSeconds, t);
    num deltaT = lerpedState.timeSeconds - timeSeconds;

    if (deltaT < 0) {
      return endVal.interpolate(this, 1 - t);
    }

    num lerpedXVel =
        MathUtil.interpolate(fieldSpeeds.vx, endVal.fieldSpeeds.vx, t);
    num lerpedYVel =
        MathUtil.interpolate(fieldSpeeds.vy, endVal.fieldSpeeds.vy, t);
    num lerpedRotVel =
        MathUtil.interpolate(fieldSpeeds.omega, endVal.fieldSpeeds.omega, t);
    lerpedState.fieldSpeeds =
        ChassisSpeeds(vx: lerpedXVel, vy: lerpedYVel, omega: lerpedRotVel);
    lerpedState.pose = pose.interpolate(endVal.pose, t);
    lerpedState.deltaPos = MathUtil.interpolate(deltaPos, endVal.deltaPos, t);
    lerpedState.deltaRot = deltaRot.interpolate(endVal.deltaRot, t);

    return lerpedState;
  }
}

class SwerveModuleTrajState extends SwerveModuleState {
  Rotation2d fieldAngle = Rotation2d();
  Translation2d fieldPos = const Translation2d();

  num deltaPos = 0.0;
}
