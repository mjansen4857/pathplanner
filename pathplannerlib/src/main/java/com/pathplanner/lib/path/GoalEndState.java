package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import java.util.Objects;
import org.json.simple.JSONObject;

/** Describes the goal end state of the robot when finishing a path */
public class GoalEndState {
  private final double velocity;
  private final Rotation2d rotation;
  private final boolean rotateFast;

  /**
   * Create a new goal end state
   *
   * @param velocity The goal end velocity (M/S)
   * @param rotation The goal rotation
   * @param rotateFast Should the robot reach the rotation as fast as possible
   */
  public GoalEndState(double velocity, Rotation2d rotation, boolean rotateFast) {
    this.velocity = velocity;
    this.rotation = rotation;
    this.rotateFast = rotateFast;
  }

  /**
   * Create a new goal end state
   *
   * @param velocity The goal end velocity (M/S)
   * @param rotation The goal rotation
   */
  public GoalEndState(double velocity, Rotation2d rotation) {
    this(velocity, rotation, false);
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
    boolean rotateFast = false;
    if (endStateJson.get("rotateFast") != null) {
      rotateFast = (boolean) endStateJson.get("rotateFast");
    }
    return new GoalEndState(vel, Rotation2d.fromDegrees(deg), rotateFast);
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

  /**
   * Get if the robot should reach the rotation as fast as possible
   *
   * @return True if the robot should reach the rotation as fast as possible
   */
  public boolean shouldRotateFast() {
    return rotateFast;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    GoalEndState that = (GoalEndState) o;
    return Math.abs(that.velocity - velocity) < 1E-3
        && Objects.equals(rotation, that.rotation)
        && rotateFast == that.rotateFast;
  }

  @Override
  public int hashCode() {
    return Objects.hash(velocity, rotation, rotateFast);
  }

  @Override
  public String toString() {
    return "GoalEndState{"
        + "velocity="
        + velocity
        + ", rotation="
        + rotation
        + ", rotateFast="
        + rotateFast
        + "}";
  }
}
