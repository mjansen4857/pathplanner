package com.pathplanner.lib.path;

import com.pathplanner.lib.util.FlippingUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import org.json.simple.JSONObject;

/**
 * Describes the goal end state of the robot when finishing a path
 *
 * @param velocity The goal end velocity (M/S)
 * @param rotation The goal rotation
 */
public record GoalEndState(double velocity, Rotation2d rotation) {
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
    return new GoalEndState(velocity, FlippingUtil.flipFieldRotation(rotation));
  }
}
