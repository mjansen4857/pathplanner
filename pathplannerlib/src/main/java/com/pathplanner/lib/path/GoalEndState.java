package com.pathplanner.lib.path;

import static edu.wpi.first.units.Units.MetersPerSecond;

import com.pathplanner.lib.util.FlippingUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.units.measure.LinearVelocity;
import org.json.simple.JSONObject;

/**
 * Describes the goal end state of the robot when finishing a path
 *
 * @param velocityMPS The goal end velocity (M/S)
 * @param rotation The goal rotation
 */
public record GoalEndState(double velocityMPS, Rotation2d rotation) {
  /**
   * Describes the goal end state of the robot when finishing a path
   *
   * @param velocity The goal end velocity
   * @param rotation The goal rotation
   */
  public GoalEndState(LinearVelocity velocity, Rotation2d rotation) {
    this(velocity.in(MetersPerSecond), rotation);
  }

  /**
   * Create a goal end state from json
   *
   * @param endStateJson {@link org.json.simple.JSONObject} representing a goal end state
   * @return The goal end state defined by the given json
   */
  static GoalEndState fromJson(JSONObject endStateJson) {
    double vel = ((Number) endStateJson.get("velocity")).doubleValue();
    double deg = ((Number) endStateJson.get("rotation")).doubleValue();
    return new GoalEndState(vel, Rotation2d.fromDegrees(deg));
  }

  /**
   * Flip the goal end state for the other side of the field, maintaining a blue alliance origin
   *
   * @return The flipped end state
   */
  public GoalEndState flip() {
    return new GoalEndState(velocityMPS, FlippingUtil.flipFieldRotation(rotation));
  }

  /**
   * Get the end linear velocity
   *
   * @return End linear velocity
   */
  public LinearVelocity velocity() {
    return MetersPerSecond.of(velocityMPS);
  }
}
