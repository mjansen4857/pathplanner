package com.pathplanner.lib.path;

import static org.junit.jupiter.api.Assertions.*;

import edu.wpi.first.math.util.Units;
import org.json.simple.JSONObject;
import org.junit.jupiter.api.Test;

public class ConstraintsZoneTest {
  public static final double DELTA = 1e-3;

  @Test
  public void testGetters() {
    ConstraintsZone zone = new ConstraintsZone(1.25, 1.8, new PathConstraints(1, 2, 3, 4));

    assertEquals(1.25, zone.getMinWaypointPos(), DELTA);
    assertEquals(1.8, zone.getMaxWaypointPos(), DELTA);
    assertEquals(new PathConstraints(1, 2, 3, 4), zone.getConstraints());
  }

  @Test
  public void testWithinZone() {
    ConstraintsZone zone = new ConstraintsZone(1.25, 1.8, new PathConstraints(1, 2, 3, 4));

    assertTrue(zone.isWithinZone(1.5));
    assertFalse(zone.isWithinZone(2.0));
    assertFalse(zone.isWithinZone(1.0));
  }

  @Test
  public void testOverlapsRange() {
    ConstraintsZone zone = new ConstraintsZone(1.25, 1.8, new PathConstraints(1, 2, 3, 4));

    assertTrue(zone.overlapsRange(1.0, 2.0));
    assertFalse(zone.overlapsRange(0.0, 1.0));
    assertFalse(zone.overlapsRange(2.0, 3.0));
  }

  @Test
  public void testFromJson() {
    JSONObject json = new JSONObject();
    JSONObject constraintsJson = new JSONObject();
    constraintsJson.put("maxVelocity", 1.0);
    constraintsJson.put("maxAcceleration", 2.0);
    constraintsJson.put("maxAngularVelocity", 90.0);
    constraintsJson.put("maxAngularAcceleration", 180.0);
    json.put("minWaypointRelativePos", 1.5);
    json.put("maxWaypointRelativePos", 2.5);
    json.put("constraints", constraintsJson);

    ConstraintsZone expected =
        new ConstraintsZone(
            1.5,
            2.5,
            new PathConstraints(1, 2, Units.degreesToRadians(90), Units.degreesToRadians(180)));
    assertEquals(expected, ConstraintsZone.fromJson(json));
  }
}
