package com.pathplanner.lib;

import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

public class PathPoint {
  public final Translation2d position;
  public final Rotation2d heading;
  public final Rotation2d holonomicRotation;
  public final double velocityOverride;

  public double prevControlLength = -1;
  public double nextControlLength = -1;

  public PathPoint(
      Translation2d position,
      Rotation2d heading,
      Rotation2d holonomicRotation,
      double velocityOverride) {
    this.position = position;
    this.heading = heading;
    this.holonomicRotation = holonomicRotation;
    this.velocityOverride = velocityOverride;
  }

  public PathPoint(Translation2d position, Rotation2d heading, Rotation2d holonomicRotation) {
    this(position, heading, holonomicRotation, -1);
  }

  public PathPoint(Translation2d position, Rotation2d heading, double velocityOverride) {
    this(position, heading, Rotation2d.fromDegrees(0), velocityOverride);
  }

  public PathPoint(Translation2d position, Rotation2d heading) {
    this(position, heading, Rotation2d.fromDegrees(0));
  }

  public PathPoint withPrevControlLength(double lengthMeters) {
    if (lengthMeters <= 0) {
      throw new IllegalArgumentException("Control point lengths must be > 0");
    }

    prevControlLength = lengthMeters;
    return this;
  }

  public PathPoint withNextControlLength(double lengthMeters) {
    if (lengthMeters <= 0) {
      throw new IllegalArgumentException("Control point lengths must be > 0");
    }

    nextControlLength = lengthMeters;
    return this;
  }

  public PathPoint withControlLengths(
      double prevControlLengthMeters, double nextControlLengthMeters) {
    if (prevControlLengthMeters <= 0 || nextControlLengthMeters <= 0) {
      throw new IllegalArgumentException("Control point lengths must be > 0");
    }

    prevControlLength = prevControlLengthMeters;
    nextControlLength = nextControlLengthMeters;
    return this;
  }

  public static PathPoint fromCurrentHolonomicState(
      Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    double linearVel =
        Math.sqrt(
            (currentSpeeds.vxMetersPerSecond * currentSpeeds.vxMetersPerSecond)
                + (currentSpeeds.vyMetersPerSecond * currentSpeeds.vyMetersPerSecond));
    Rotation2d heading =
        new Rotation2d(
            Math.atan2(currentSpeeds.vyMetersPerSecond, currentSpeeds.vxMetersPerSecond));
    return new PathPoint(
        currentPose.getTranslation(), heading, currentPose.getRotation(), linearVel);
  }

  public static PathPoint fromCurrentDifferentialState(
      Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    return new PathPoint(
        currentPose.getTranslation(), currentPose.getRotation(), currentSpeeds.vxMetersPerSecond);
  }

  /**
   * Checks equality between this PathPoint and another object.
   *
   * @param obj The other object.
   * @return Whether the two objects are equal or not.
   */
  @Override
  public boolean equals(Object obj) {
    if (obj instanceof PathPoint) {
      return ((PathPoint) obj).position.equals(position)
          && ((PathPoint) obj).heading.equals(heading)
          && ((PathPoint) obj).holonomicRotation.equals(holonomicRotation);
    }
    return false;
  }
}
