package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.Objects;

/** A point along a pathplanner path */
public class PathPoint {
  /** The position of this point */
  public final Translation2d position;

  /** The distance of this point along the path, in meters */
  public double distanceAlongPath = 0.0;
  /** The curve radius at this point */
  public double curveRadius = 0.0;
  /** The max velocity at this point */
  public double maxV = Double.POSITIVE_INFINITY;
  /** The target rotation at this point */
  public Rotation2d holonomicRotation = null;
  /** The constraints applied to this point */
  public PathConstraints constraints = null;

  /**
   * Create a path point
   *
   * @param position Position of the point
   * @param holonomicRotation Rotation target at this point
   * @param constraints The constraints at this point
   */
  public PathPoint(
      Translation2d position, Rotation2d holonomicRotation, PathConstraints constraints) {
    this.position = position;
    this.holonomicRotation = holonomicRotation;
    this.constraints = constraints;
  }

  /**
   * Create a path point
   *
   * @param position Position of the point
   * @param holonomicRotation Rotation target at this point
   */
  public PathPoint(Translation2d position, Rotation2d holonomicRotation) {
    this.position = position;
    this.holonomicRotation = holonomicRotation;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    PathPoint pathPoint = (PathPoint) o;
    return Math.abs(pathPoint.distanceAlongPath - distanceAlongPath) < 1E-3
        && Math.abs(pathPoint.maxV - maxV) < 1E-3
        && Objects.equals(position, pathPoint.position)
        && Objects.equals(holonomicRotation, pathPoint.holonomicRotation)
        && Objects.equals(constraints, pathPoint.constraints);
  }

  @Override
  public int hashCode() {
    return Objects.hash(position, distanceAlongPath, maxV, holonomicRotation, constraints);
  }
}
