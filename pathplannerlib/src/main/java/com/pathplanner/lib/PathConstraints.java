package com.pathplanner.lib;

public class PathConstraints {
  public final double maxVelocity;
  public final double maxAcceleration;

  public PathConstraints(double maxVelocity, double maxAcceleration) {
    this.maxVelocity = maxVelocity;
    this.maxAcceleration = maxAcceleration;
  }
}
