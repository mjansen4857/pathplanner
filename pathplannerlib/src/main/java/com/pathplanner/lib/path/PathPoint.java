package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;

public class PathPoint {
  public final Translation2d position;

  public double distanceAlongPath = 0.0;
  public double maxV = Double.POSITIVE_INFINITY;
  public Rotation2d holonomicRotation = null;
  public PathConstraints constraints = null;

  public PathPoint(
      Translation2d position, Rotation2d holonomicRotation, PathConstraints constraints) {
    this.position = position;
    this.holonomicRotation = holonomicRotation;
    this.constraints = constraints;
  }

  public PathPoint(Translation2d position, PathConstraints constraints) {
    this.position = position;
    this.constraints = constraints;
  }

  public PathPoint(Translation2d position, Rotation2d holonomicRotation) {
    this.position = position;
    this.holonomicRotation = holonomicRotation;
  }

  public PathPoint(Translation2d position) {
    this.position = position;
  }
}
