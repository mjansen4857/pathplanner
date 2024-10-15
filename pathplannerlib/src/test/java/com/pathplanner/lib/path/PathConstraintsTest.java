package com.pathplanner.lib.path;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.wpi.first.math.util.Units;
import org.json.simple.JSONObject;
import org.junit.jupiter.api.Test;

public class PathConstraintsTest {
  public static final double DELTA = 1e-3;

  @Test
  public void testGetters() {
    PathConstraints constraints = new PathConstraints(1.0, 2.0, 3.0, 4.0);

    assertEquals(1.0, constraints.maxVelocityMPS(), DELTA);
    assertEquals(2.0, constraints.maxAccelerationMPSSq(), DELTA);
    assertEquals(3.0, constraints.maxAngularVelocityRadPerSec(), DELTA);
    assertEquals(4.0, constraints.maxAngularAccelerationRadPerSecSq(), DELTA);
  }

  @Test
  public void testFromJson() {
    JSONObject json = new JSONObject();
    json.put("maxVelocity", 1.0);
    json.put("maxAcceleration", 2.0);
    json.put("maxAngularVelocity", 90.0);
    json.put("maxAngularAcceleration", 180.0);
    json.put("nominalVoltage", 12.0);
    json.put("unlimited", false);

    PathConstraints fromJson = PathConstraints.fromJson(json);

    assertEquals(
        new PathConstraints(
            1.0, 2.0, Units.degreesToRadians(90), Units.degreesToRadians(180), 12.0, false),
        fromJson);
  }
}
