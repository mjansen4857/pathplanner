package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.Objects;

public class PathPoint {
  public final Translation2d position;

  public double distanceAlongPath = 0.0;
  public double curveRadius = 0.0;
  public double maxV = Double.POSITIVE_INFINITY;
  public Rotation2d holonomicRotation = null;
  public PathConstraints constraints = null;

  public PathPoint(
      Translation2d position, Rotation2d holonomicRotation, PathConstraints constraints) {
    this.position = position;
    this.holonomicRotation = holonomicRotation;
    this.constraints = constraints;
  }

  public PathPoint(Translation2d position, Rotation2d holonomicRotation) {
    this.position = position;
    this.holonomicRotation = holonomicRotation;
  }

  public PathPoint(Translation2d position) {
    this.position = position;
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
