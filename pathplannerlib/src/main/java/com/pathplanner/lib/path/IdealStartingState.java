package com.pathplanner.lib.path;

import static edu.wpi.first.units.Units.MetersPerSecond;

import com.pathplanner.lib.util.FlippingUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.units.measure.LinearVelocity;
import org.json.simple.JSONObject;

/**
 * Describes the ideal starting state of the robot when finishing a path
 *
 * @param velocityMPS The ideal starting velocity (M/S)
 * @param rotation The ideal starting rotation
 */
public record IdealStartingState(double velocityMPS, Rotation2d rotation) {
  /**
   * Describes the ideal starting state of the robot when finishing a path
   *
   * @param velocity The ideal starting velocity
   * @param rotation The ideal starting rotation
   */
  public IdealStartingState(LinearVelocity velocity, Rotation2d rotation) {
    this(velocity.in(MetersPerSecond), rotation);
  }

  /**
   * Create an ideal starting state from json
   *
   * @param startingStateJson {@link JSONObject} representing a goal end state
   * @return The goal end state defined by the given json
   */
  static IdealStartingState fromJson(JSONObject startingStateJson) {
    double vel = ((Number) startingStateJson.get("velocity")).doubleValue();
    double deg = ((Number) startingStateJson.get("rotation")).doubleValue();
    return new IdealStartingState(vel, Rotation2d.fromDegrees(deg));
  }

  /**
   * Flip the ideal starting state for the other side of the field, maintaining a blue alliance
   * origin
   *
   * @return The flipped starting state
   */
  public IdealStartingState flip() {
    return new IdealStartingState(velocityMPS, FlippingUtil.flipFieldRotation(rotation));
  }

  /**
   * Get the starting linear velocity
   *
   * @return Starting linear velocity
   */
  public LinearVelocity velocity() {
    return MetersPerSecond.of(velocityMPS);
  }
}
