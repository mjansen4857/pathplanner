package com.pathplanner.lib;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import org.junit.jupiter.api.Test;

public class GeometryUtilTest {
  public static final double DELTA = 1e-3;

  @Test
  public void testDoubleLerp() {
    assertEquals(0.5, GeometryUtil.doubleLerp(0, 1, 0.5), DELTA);
    assertEquals(12, GeometryUtil.doubleLerp(10, 20, 0.2), DELTA);
    assertEquals(-118, GeometryUtil.doubleLerp(-100, -120, 0.9), DELTA);
    assertEquals(0, GeometryUtil.doubleLerp(0, 1, 0), DELTA);
    assertEquals(1, GeometryUtil.doubleLerp(0, 1, 1), DELTA);
  }

  @Test
  public void testRotationLerp() {
    assertEquals(
        90,
        GeometryUtil.rotationLerp(Rotation2d.fromDegrees(0), Rotation2d.fromDegrees(180), 0.5)
            .getDegrees(),
        DELTA);
    assertEquals(
        -45,
        GeometryUtil.rotationLerp(Rotation2d.fromDegrees(0), Rotation2d.fromDegrees(-180), 0.25)
            .getDegrees(),
        DELTA);
  }

  @Test
  public void testTranslationLerp() {
    Translation2d t =
        GeometryUtil.translationLerp(new Translation2d(2.3, 7), new Translation2d(3.5, 2.1), 0.2);
    assertEquals(2.54, t.getX(), DELTA);
    assertEquals(6.02, t.getY(), DELTA);

    t = GeometryUtil.translationLerp(new Translation2d(-1.5, 2), new Translation2d(1.5, -3), 0.5);
    assertEquals(0, t.getX(), DELTA);
    assertEquals(-0.5, t.getY(), DELTA);
  }

  @Test
  public void testQuadraticLerp() {
    Translation2d t =
        GeometryUtil.quadraticLerp(
            new Translation2d(1, 2), new Translation2d(3, 4), new Translation2d(5, 6), 0.5);
    assertEquals(3, t.getX(), DELTA);
    assertEquals(4, t.getY(), DELTA);
  }

  @Test
  public void testCubicLerp() {
    Translation2d t =
        GeometryUtil.cubicLerp(
            new Translation2d(1, 2),
            new Translation2d(3, 4),
            new Translation2d(5, 6),
            new Translation2d(7, 8),
            0.5);
    assertEquals(4, t.getX(), DELTA);
    assertEquals(5, t.getY(), DELTA);
  }
}
