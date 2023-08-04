package com.pathplanner.lib.path;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.wpi.first.math.geometry.Rotation2d;
import org.json.simple.JSONObject;
import org.junit.jupiter.api.Test;

public class GoalEndStateTest {
  public static final double DELTA = 1e-3;

  @Test
  public void testGetters() {
    GoalEndState endState = new GoalEndState(2.0, Rotation2d.fromDegrees(35));

    assertEquals(2.0, endState.getVelocity(), DELTA);
    assertEquals(Rotation2d.fromDegrees(35), endState.getRotation());
  }

  @Test
  public void testFromJson() {
    JSONObject json = new JSONObject();
    json.put("velocity", 1.25);
    json.put("rotation", -15.5);

    assertEquals(
        new GoalEndState(1.25, Rotation2d.fromDegrees(-15.5)), GoalEndState.fromJson(json));
  }
}
