package com.pathplanner.lib.trajectory;

import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.util.DriveFeedforward;
import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.interpolation.Interpolatable;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

/** A state along the a {@link com.pathplanner.lib.trajectory.PathPlannerTrajectory} */
public class PathPlannerTrajectoryState implements Interpolatable<PathPlannerTrajectoryState> {
  /** The time at this state in seconds */
  public double timeSeconds = 0.0;
  /** Field-relative chassis speeds at this state */
  public ChassisSpeeds fieldSpeeds = new ChassisSpeeds();
  /** Field-relative robot pose at this state */
  public Pose2d pose = new Pose2d();
  /** The linear velocity at this state in m/s */
  public double linearVelocity = 0.0;

  /** The feedforwards for each module */
  public DriveFeedforward[] feedforwards;

  // Values used only during generation, these will not be interpolated
  /** The field-relative heading, or direction of travel, at this state */
  protected Rotation2d heading = new Rotation2d();
  /** The distance between this state and the previous state */
  protected double deltaPos = 0.0;
  /** The difference in rotation between this state and the previous state */
  protected Rotation2d deltaRot = new Rotation2d();
  /**
   * The {@link com.pathplanner.lib.trajectory.SwerveModuleTrajectoryState} states for this state
   */
  protected SwerveModuleTrajectoryState[] moduleStates;
  /** The {@link com.pathplanner.lib.path.PathConstraints} for this state */
  protected PathConstraints constraints;
  /** The waypoint relative position of this state. Used to determine proper event marker timing */
  protected double waypointRelativePos = 0.0;

  /**
   * Interpolate between this state and the given state
   *
   * @param endVal State to interpolate with
   * @param t Interpolation factor (0.0-1.0)
   * @return Interpolated state
   */
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
    lerpedState.feedforwards = new DriveFeedforward[feedforwards.length];
    for (int m = 0; m < feedforwards.length; m++) {
      lerpedState.feedforwards[m] = feedforwards[m].interpolate(endVal.feedforwards[m], t);
    }

    return lerpedState;
  }

  /**
   * Get the state reversed, used for following a trajectory reversed with a differential drivetrain
   *
   * @return The reversed state
   */
  public PathPlannerTrajectoryState reverse() {
    var reversed = new PathPlannerTrajectoryState();

    reversed.timeSeconds = timeSeconds;
    Translation2d reversedSpeeds =
        new Translation2d(fieldSpeeds.vxMetersPerSecond, fieldSpeeds.vyMetersPerSecond)
            .rotateBy(Rotation2d.fromDegrees(180));
    reversed.fieldSpeeds =
        new ChassisSpeeds(
            reversedSpeeds.getX(), reversedSpeeds.getY(), fieldSpeeds.omegaRadiansPerSecond);
    reversed.pose =
        new Pose2d(pose.getTranslation(), pose.getRotation().plus(Rotation2d.fromDegrees(180)));
    reversed.linearVelocity = -linearVelocity;
    reversed.feedforwards = new DriveFeedforward[feedforwards.length];
    for (int m = 0; m < feedforwards.length; m++) {
      reversed.feedforwards[m] = feedforwards[m].reverse();
    }

    return reversed;
  }

  /**
   * Flip this trajectory state for the other side of the field, maintaining a blue alliance origin
   *
   * @return This trajectory state flipped to the other side of the field
   */
  public PathPlannerTrajectoryState flip() {
    var mirrored = new PathPlannerTrajectoryState();

    mirrored.timeSeconds = timeSeconds;
    mirrored.linearVelocity = linearVelocity;
    mirrored.pose = GeometryUtil.flipFieldPose(pose);
    mirrored.fieldSpeeds =
        new ChassisSpeeds(
            -fieldSpeeds.vxMetersPerSecond,
            fieldSpeeds.vyMetersPerSecond,
            -fieldSpeeds.omegaRadiansPerSecond);
    if (feedforwards.length == 4) {
      mirrored.feedforwards =
          new DriveFeedforward[] {
            feedforwards[1], feedforwards[0], feedforwards[3], feedforwards[2],
          };
    } else if (feedforwards.length == 2) {
      mirrored.feedforwards =
          new DriveFeedforward[] {
            feedforwards[1], feedforwards[0],
          };
    }

    return mirrored;
  }
}
