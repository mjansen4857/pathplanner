package com.pathplanner.lib.trajectory;

import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

public class PathPlannerTrajectoryState {
  public double timeSeconds = 0.0;
  public ChassisSpeeds fieldSpeeds = new ChassisSpeeds();
  public Pose2d pose = Pose2d.kZero;

  // Values used only during generation, these will not be interpolated
  protected Rotation2d heading = Rotation2d.kZero;
  protected double deltaPos = 0.0;
  protected Rotation2d deltaRot = Rotation2d.kZero;
  protected SwerveModuleTrajectoryState[] moduleStates;

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

    return lerpedState;
  }
}
