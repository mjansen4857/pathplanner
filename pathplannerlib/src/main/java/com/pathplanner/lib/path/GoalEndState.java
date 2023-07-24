package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import org.json.simple.JSONObject;

public class GoalEndState {
  private final double velocity;
  private final Rotation2d rotation;

  public GoalEndState(double velocity, Rotation2d rotation) {
    this.velocity = velocity;
    this.rotation = rotation;
  }

  public GoalEndState(Rotation2d rotation) {
    this(0, rotation);
  }

  public GoalEndState() {
    this(0, new Rotation2d());
  }

  static GoalEndState fromJson(JSONObject endStateJson) {
    double vel = ((Number) endStateJson.get("velocity")).doubleValue();
    double deg = ((Number) endStateJson.get("rotation")).doubleValue();
    return new GoalEndState(vel, Rotation2d.fromDegrees(deg));
  }

  public double getVelocity() {
    return velocity;
  }

  public Rotation2d getRotation() {
    return rotation;
  }
}
