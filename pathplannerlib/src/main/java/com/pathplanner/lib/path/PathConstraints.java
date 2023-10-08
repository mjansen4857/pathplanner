package com.pathplanner.lib.path;

import edu.wpi.first.math.util.Units;
import java.util.Objects;
import org.json.simple.JSONObject;

/** Kinematic path following constraints */
public class PathConstraints {
  private final double maxVelocityMps;
  private final double maxAccelerationMpsSq;
  private final double maxAngularVelocityRps;
  private final double maxAngularAccelerationRpsSq;

  /**
   * Create a new path constraints object
   *
   * @param maxVelocityMps Max linear velocity (M/S)
   * @param maxAccelerationMpsSq Max linear acceleration (M/S^2)
   * @param maxAngularVelocityRps Max angular velocity (Rad/S)
   * @param maxAngularAccelerationRpsSq Max angular acceleration (Rad/S^2)
   */
  public PathConstraints(
      double maxVelocityMps,
      double maxAccelerationMpsSq,
      double maxAngularVelocityRps,
      double maxAngularAccelerationRpsSq) {
    this.maxVelocityMps = maxVelocityMps;
    this.maxAccelerationMpsSq = maxAccelerationMpsSq;
    this.maxAngularVelocityRps = maxAngularVelocityRps;
    this.maxAngularAccelerationRpsSq = maxAngularAccelerationRpsSq;
  }

  /**
   * Create a path constraints object from json
   *
   * @param constraintsJson {@link org.json.simple.JSONObject} representing a path constraints
   *     object
   * @return The path constraints defined by the given json
   */
  static PathConstraints fromJson(JSONObject constraintsJson) {
    double maxVel = ((Number) constraintsJson.get("maxVelocity")).doubleValue();
    double maxAccel = ((Number) constraintsJson.get("maxAcceleration")).doubleValue();
    double maxAngularVel =
        ((Number) constraintsJson.get("maxAngularVelocity")).doubleValue(); // Degrees
    double maxAngularAccel =
        ((Number) constraintsJson.get("maxAngularAcceleration")).doubleValue(); // Degrees

    return new PathConstraints(
        maxVel,
        maxAccel,
        Units.degreesToRadians(maxAngularVel),
        Units.degreesToRadians(maxAngularAccel));
  }

  /**
   * Get the max linear velocity
   *
   * @return Max linear velocity (M/S)
   */
  public double getMaxVelocityMps() {
    return maxVelocityMps;
  }

  /**
   * Get the max linear acceleration
   *
   * @return Max linear acceleration (M/S^2)
   */
  public double getMaxAccelerationMpsSq() {
    return maxAccelerationMpsSq;
  }

  /**
   * Get the max angular velocity
   *
   * @return Max angular velocity (Rad/S)
   */
  public double getMaxAngularVelocityRps() {
    return maxAngularVelocityRps;
  }

  /**
   * Get the max angular acceleration
   *
   * @return Max angular acceleration (Rad/S^2)
   */
  public double getMaxAngularAccelerationRpsSq() {
    return maxAngularAccelerationRpsSq;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    PathConstraints that = (PathConstraints) o;
    return Math.abs(that.maxVelocityMps - maxVelocityMps) < 1E-3
        && Math.abs(that.maxAccelerationMpsSq - maxAccelerationMpsSq) < 1E-3
        && Math.abs(that.maxAngularVelocityRps - maxAngularVelocityRps) < 1E-3
        && Math.abs(that.maxAngularAccelerationRpsSq - maxAngularAccelerationRpsSq) < 1E-3;
  }

  @Override
  public int hashCode() {
    return Objects.hash(
        maxVelocityMps, maxAccelerationMpsSq, maxAngularVelocityRps, maxAngularAccelerationRpsSq);
  }

  @Override
  public String toString() {
    return "PathConstraints{"
        + "maxVelocityMps="
        + maxVelocityMps
        + ", maxAccelerationMpsSq="
        + maxAccelerationMpsSq
        + ", maxAngularVelocityRps="
        + maxAngularVelocityRps
        + ", maxAngularAccelerationRpsSq="
        + maxAngularAccelerationRpsSq
        + '}';
  }
}
