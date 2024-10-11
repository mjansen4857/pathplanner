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
 * @param nominalVoltage The nominal battery voltage (Volts)
 * @param unlimited Should the constraints be unlimited
 */
public record PathConstraints(
    double maxVelocityMps,
    double maxAccelerationMps,
    double maxAngularVelocityRps,
    double maxAngularAccelerationRpsSq,
    double nominalVoltage,
    boolean unlimited) {
  /**
   * Kinematic path following constraints
   *
   * @param maxVelocityMps Max linear velocity (M/S)
   * @param maxAccelerationMps Max linear acceleration (M/S^2)
   * @param maxAngularVelocityRps Max angular velocity (Rad/S)
   * @param maxAngularAccelerationRpsSq Max angular acceleration (Rad/S^2)
   * @param nominalVoltage The nominal battery voltage (Volts)
   */
  public PathConstraints(
      double maxVelocityMps,
      double maxAccelerationMps,
      double maxAngularVelocityRps,
      double maxAngularAccelerationRpsSq,
      double nominalVoltage) {
    this(
        maxVelocityMps,
        maxAccelerationMps,
        maxAngularVelocityRps,
        maxAngularAccelerationRpsSq,
        nominalVoltage,
        false);
  }

  /**
   * Kinematic path following constraints
   *
   * @param maxVelocityMps Max linear velocity (M/S)
   * @param maxAccelerationMps Max linear acceleration (M/S^2)
   * @param maxAngularVelocityRps Max angular velocity (Rad/S)
   * @param maxAngularAccelerationRpsSq Max angular acceleration (Rad/S^2)
   */
  public PathConstraints(
      double maxVelocityMps,
      double maxAccelerationMps,
      double maxAngularVelocityRps,
      double maxAngularAccelerationRpsSq) {
    this(
        maxVelocityMps,
        maxAccelerationMps,
        maxAngularVelocityRps,
        maxAngularAccelerationRpsSq,
        12.0,
        false);
  }

  /**
   * Get unlimited PathConstraints
   *
   * @param nominalVoltage The nominal battery voltage (Volts)
   * @return Unlimited constraints
   */
  public static PathConstraints unlimitedConstraints(double nominalVoltage) {
    return new PathConstraints(
        Double.POSITIVE_INFINITY,
        Double.POSITIVE_INFINITY,
        Double.POSITIVE_INFINITY,
        Double.POSITIVE_INFINITY,
        nominalVoltage,
        true);
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
    double nominalVoltage = ((Number) constraintsJson.get("nominalVoltage")).doubleValue();
    boolean unlimited = ((boolean) constraintsJson.get("unlimited"));

    return new PathConstraints(
        maxVel,
        maxAccel,
        Units.degreesToRadians(maxAngularVel),
        Units.degreesToRadians(maxAngularAccel),
        nominalVoltage,
        unlimited);
  }
}
