package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import org.json.simple.JSONObject;

public class GoalEndState {
  private final double velocity;
  private final Rotation2d rotation;

  /**
   * Create a new goal end state
   *
   * @param velocity The goal end velocity (M/S)
   * @param rotation The goal rotation
   */
  public GoalEndState(double velocity, Rotation2d rotation) {
    this.velocity = velocity;
    this.rotation = rotation;
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
   * Get the goal end velocity
   *
   * @return Goal end velocity (M/S)
   */
  public double getVelocity() {
    return velocity;
  }

  /**
   * Get the goal end rotation
   *
   * @return Goal rotation
   */
  public Rotation2d getRotation() {
    return rotation;
  }
}
