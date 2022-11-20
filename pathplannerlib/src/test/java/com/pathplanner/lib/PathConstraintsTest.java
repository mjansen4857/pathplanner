package com.pathplanner.lib;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

public class PathConstraintsTest {
  public static final double DELTA = 1e-3;

  @Test
  public void constructor() {
    PathConstraints constraints = new PathConstraints(4.0, 3.0);
    assertEquals(4.0, constraints.maxVelocity, DELTA);
    assertEquals(3.0, constraints.maxAcceleration, DELTA);
  }
}
