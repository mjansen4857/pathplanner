package com.pathplanner.lib.path;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.wpi.first.math.geometry.Rotation2d;
import org.json.simple.JSONObject;
import org.junit.jupiter.api.Test;

public class RotationTargetTest {
  public static final double DELTA = 1e-3;

  @Test
  public void testGetters() {
    RotationTarget target = new RotationTarget(1.5, Rotation2d.fromDegrees(90));

    assertEquals(1.5, target.getPosition(), DELTA);
    assertEquals(Rotation2d.fromDegrees(90), target.getTarget());
  }

  @Test
  public void testForSegmentIndex() {
    RotationTarget target = new RotationTarget(1.5, Rotation2d.fromDegrees(90));
    RotationTarget forSegment = target.forSegmentIndex(1);

    assertEquals(0.5, forSegment.getPosition(), DELTA);
    assertEquals(Rotation2d.fromDegrees(90), forSegment.getTarget());
  }

  @Test
  public void testFromJson() {
    JSONObject json = new JSONObject();
    json.put("waypointRelativePos", 2.1);
    json.put("rotationDegrees", -45);

    assertEquals(
        new RotationTarget(2.1, Rotation2d.fromDegrees(-45)), RotationTarget.fromJson(json));
  }
}
