package com.pathplanner.lib.path;

import edu.wpi.first.math.util.Units;
import org.json.simple.JSONObject;

/**
 * Kinematic path following constraints
 *
 * @param maxVelocityMps Max linear velocity (M/S)
 * @param maxAccelerationMps Max linear acceleration (M/S^2)
 * @param maxAngularVelocityRps Max angular velocity (Rad/S)
 * @param maxAngularAccelerationRpsSq Max angular acceleration (Rad/S^2)
 */
public record PathConstraints(
    double maxVelocityMps,
    double maxAccelerationMps,
    double maxAngularVelocityRps,
    double maxAngularAccelerationRpsSq) {
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
}
