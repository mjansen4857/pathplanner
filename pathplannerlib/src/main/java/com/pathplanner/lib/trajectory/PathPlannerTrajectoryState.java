package com.pathplanner.lib.trajectory;

import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.util.DriveFeedforwards;
import com.pathplanner.lib.util.FlippingUtil;
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
  public Pose2d pose = Pose2d.kZero;
  /** The linear velocity at this state in m/s */
  public double linearVelocity = 0.0;
  /** The field-relative heading, or direction of travel, at this state */
  public Rotation2d heading = Rotation2d.kZero;
  /** The cumulative arc length traveled along the path to reach this state, in meters */
  public double distanceAlongPath = 0.0;
  /**
   * The signed path curvature at this state in radians per meter (1/m). Positive curves left,
   * negative curves right. Used by curvature-feedforward path-following controllers.
   */
  public double curvatureRadPerMeter = 0.0;

  /** The feedforwards for each module */
  public DriveFeedforwards feedforwards;

  // Values used only during generation, these will not be interpolated
  /** The distance between this state and the previous state */
  protected double deltaPos = 0.0;
  /** The difference in rotation between this state and the previous state */
  protected Rotation2d deltaRot = Rotation2d.kZero;
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

    // heading is the chord direction (state[k] -> state[k+1]) and is constant along a segment.
    // Integration below uses this start-state heading throughout, which keeps the integrated
    // position on the chord rather than drifting toward the underlying curve. Callers reading
    // targetState.heading see the current-segment chord direction, which is the correct
    // tangent for perpendicular cross-track measurement.
    lerpedState.heading = heading;
    lerpedState.linearVelocity = MathUtil.interpolate(linearVelocity, endVal.linearVelocity, t);
    lerpedState.distanceAlongPath =
        MathUtil.interpolate(distanceAlongPath, endVal.distanceAlongPath, t);
    lerpedState.curvatureRadPerMeter =
        MathUtil.interpolate(curvatureRadPerMeter, endVal.curvatureRadPerMeter, t);

    // Integrate the field speeds to get the pose for this interpolated state, since linearly
    // interpolating the pose gives an inaccurate result if the speeds are changing between
    // states. Forward Euler with 10 ms steps, plus a remainder step for the last partial
    // interval. Linear velocity is lerped per step; heading stays constant (the chord
    // direction).
    double lerpedXPos = pose.getX();
    double lerpedYPos = pose.getY();
    if (deltaT > 0) {
      double cosH = heading.getCos();
      double sinH = heading.getSin();
      double intTime = timeSeconds;
      while (true) {
        double intT = (intTime - timeSeconds) / deltaT;
        double intLinearVel = MathUtil.interpolate(linearVelocity, endVal.linearVelocity, intT);
        double intVX = intLinearVel * cosH;
        double intVY = intLinearVel * sinH;

        double remainingTime = lerpedState.timeSeconds - intTime;
        if (remainingTime <= 0.01) {
          lerpedXPos += intVX * remainingTime;
          lerpedYPos += intVY * remainingTime;
          break;
        }

        lerpedXPos += intVX * 0.01;
        lerpedYPos += intVY * 0.01;
        intTime += 0.01;
      }
    }
    // If deltaT == 0, pose stays at this.pose -- no integration needed, no divide-by-zero.

    lerpedState.pose =
        new Pose2d(
            lerpedXPos, lerpedYPos, pose.getRotation().interpolate(endVal.pose.getRotation(), t));
    lerpedState.feedforwards = feedforwards.interpolate(endVal.feedforwards, t);

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
            .rotateBy(Rotation2d.k180deg);
    reversed.fieldSpeeds =
        new ChassisSpeeds(
            reversedSpeeds.getX(), reversedSpeeds.getY(), fieldSpeeds.omegaRadiansPerSecond);
    reversed.pose = new Pose2d(pose.getTranslation(), pose.getRotation().plus(Rotation2d.k180deg));
    reversed.linearVelocity = -linearVelocity;
    reversed.feedforwards = feedforwards.reverse();
    reversed.heading = heading.plus(Rotation2d.k180deg);
    reversed.distanceAlongPath = distanceAlongPath;
    // Reversing direction of travel flips the sign of curvature (left becomes right).
    reversed.curvatureRadPerMeter = -curvatureRadPerMeter;

    return reversed;
  }

  /**
   * Flip this trajectory state for the other side of the field, maintaining a blue alliance origin
   *
   * @return This trajectory state flipped to the other side of the field
   */
  public PathPlannerTrajectoryState flip() {
    var flipped = new PathPlannerTrajectoryState();

    flipped.timeSeconds = timeSeconds;
    flipped.linearVelocity = linearVelocity;
    flipped.pose = FlippingUtil.flipFieldPose(pose);
    flipped.fieldSpeeds = FlippingUtil.flipFieldSpeeds(fieldSpeeds);
    flipped.feedforwards = feedforwards.flip();
    flipped.heading = FlippingUtil.flipFieldRotation(heading);
    flipped.distanceAlongPath = distanceAlongPath;
    // Sign of signed curvature is preserved under 180-deg rotation (chirality preserved) but
    // inverted under mirror reflection (chirality flipped).
    flipped.curvatureRadPerMeter =
        switch (FlippingUtil.symmetryType) {
          case kMirrored -> -curvatureRadPerMeter;
          case kRotational -> curvatureRadPerMeter;
        };

    return flipped;
  }

  /**
   * Copy this state and change the timestamp
   *
   * @param time The new time to use
   * @return Copied state with the given time
   */
  public PathPlannerTrajectoryState copyWithTime(double time) {
    PathPlannerTrajectoryState copy = new PathPlannerTrajectoryState();
    copy.timeSeconds = time;
    copy.fieldSpeeds = fieldSpeeds;
    copy.pose = pose;
    copy.linearVelocity = linearVelocity;
    copy.feedforwards = feedforwards;
    copy.heading = heading;
    copy.distanceAlongPath = distanceAlongPath;
    copy.curvatureRadPerMeter = curvatureRadPerMeter;
    copy.deltaPos = deltaPos;
    copy.deltaRot = deltaRot;
    copy.moduleStates = moduleStates;
    copy.constraints = constraints;
    copy.waypointRelativePos = waypointRelativePos;

    return copy;
  }
}
