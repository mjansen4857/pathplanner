package com.pathplanner.lib.util;

import static org.junit.jupiter.api.Assertions.assertEquals;

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
}
