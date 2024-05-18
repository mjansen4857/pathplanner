package com.pathplanner.lib.trajectory;

import com.pathplanner.lib.path.PathConstraints;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

public class PathPlannerTrajectoryState {
  public double timeSeconds = 0.0;
  public ChassisSpeeds fieldSpeeds = new ChassisSpeeds();
  public Pose2d pose = Pose2d.kZero;
  public double linearVelocity = 0.0;

  // Values used only during generation, these will not be interpolated
  protected Rotation2d heading = Rotation2d.kZero;
  protected double deltaPos = 0.0;
  protected Rotation2d deltaRot = Rotation2d.kZero;
  protected SwerveModuleTrajectoryState[] moduleStates;
  protected PathConstraints constraints;

  public PathPlannerTrajectoryState interpolate(PathPlannerTrajectoryState endVal, double t) {
    var lerpedState = new PathPlannerTrajectoryState();

    lerpedState.timeSeconds = MathUtil.interpolate(timeSeconds, endVal.timeSeconds, t);

    double deltaT = lerpedState.timeSeconds - timeSeconds;
    if (deltaT < 0) {
      return endVal.interpolate(this, 1 - t);
    }

    lerpedState.fieldSpeeds =
        new ChassisSpeeds(
            MathUtil.interpolate(
                fieldSpeeds.vxMetersPerSecond, endVal.fieldSpeeds.vxMetersPerSecond, t),
            MathUtil.interpolate(
                fieldSpeeds.vyMetersPerSecond, endVal.fieldSpeeds.vyMetersPerSecond, t),
            MathUtil.interpolate(
                fieldSpeeds.omegaRadiansPerSecond, endVal.fieldSpeeds.omegaRadiansPerSecond, t));
    lerpedState.pose = pose.interpolate(endVal.pose, t);
    lerpedState.linearVelocity = MathUtil.interpolate(linearVelocity, endVal.linearVelocity, t);

    return lerpedState;
  }

  public PathPlannerTrajectoryState reverse() {
    var reversed = new PathPlannerTrajectoryState();

    reversed.timeSeconds = timeSeconds;
    Translation2d reversedSpeeds =
        new Translation2d(fieldSpeeds.vxMetersPerSecond, fieldSpeeds.vyMetersPerSecond)
            .rotateBy(Rotation2d.k180deg);
    reversed.fieldSpeeds =
        new ChassisSpeeds(
            reversedSpeeds.getX(), reversedSpeeds.getY(), fieldSpeeds.omegaRadiansPerSecond);
    reversed.pose = new Pose2d(pose.getTranslation(), pose.getRotation().plus(Rotation2d.k180deg));
    reversed.linearVelocity = -linearVelocity;

    return reversed;
  }
}
