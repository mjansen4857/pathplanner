package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import java.util.Objects;
import org.json.simple.JSONObject;

/** Describes the ideal starting state of the robot when finishing a path */
public class IdealStartingState {
  private final double velocity;
  private final Rotation2d rotation;

  /**
   * Create a new ideal starting state
   *
   * @param velocity The ideal starting velocity (M/S)
   * @param rotation The ideal starting rotation
   */
  public IdealStartingState(double velocity, Rotation2d rotation) {
    this.velocity = velocity;
    this.rotation = rotation;
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
   * Get the ideal starting velocity
   *
   * @return Ideal starting velocity (M/S)
   */
  public double getVelocity() {
    return velocity;
  }

  /**
   * Get the ideal starting rotation
   *
   * @return Ideal starting rotation
   */
  public Rotation2d getRotation() {
    return rotation;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    IdealStartingState that = (IdealStartingState) o;
    return Math.abs(that.velocity - velocity) < 1E-3 && Objects.equals(rotation, that.rotation);
  }

  @Override
  public int hashCode() {
    return Objects.hash(velocity, rotation);
  }

  @Override
  public String toString() {
    return "IdealStartingState{" + "velocity=" + velocity + ", rotation=" + rotation + "}";
  }
}
