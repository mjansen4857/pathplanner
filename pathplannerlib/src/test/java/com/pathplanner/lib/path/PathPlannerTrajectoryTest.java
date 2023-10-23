package com.pathplanner.lib.path;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import org.junit.jupiter.api.Test;

public class PathPlannerTrajectoryTest {
  private static final double EPSILON = 1e-6;

  @Test
  public void testReverse() {
    PathPlannerTrajectory.State state = new PathPlannerTrajectory.State();
    state.timeSeconds = 1.91;
    state.velocityMps = 2.29;
    state.accelerationMpsSq = 35.04;
    state.headingAngularVelocityRps = 174;
    state.positionMeters = new Translation2d(1.1, 2.2);
    state.heading = Rotation2d.fromDegrees(191);
    state.targetHolonomicRotation = Rotation2d.fromDegrees(22.9);
    state.curvatureRadPerMeter = 3.504;
    state.constraints = new PathConstraints(1, 2, 3, 4);

    // Round-trip reversal should yield the original state
    state = state.reverse();
    state = state.reverse();

    assertEquals(1.91, state.timeSeconds, EPSILON);
    assertEquals(2.29, state.velocityMps, EPSILON);
    assertEquals(35.04, state.accelerationMpsSq, EPSILON);
    assertEquals(174, state.headingAngularVelocityRps);
    assertEquals(1.1, state.positionMeters.getX());
    assertEquals(2.2, state.positionMeters.getY());
    assertEquals(191 - 360, state.heading.getDegrees(), EPSILON);
    assertEquals(22.9, state.targetHolonomicRotation.getDegrees(), EPSILON);
    assertEquals(3.504, state.curvatureRadPerMeter);
    assertEquals(1, state.constraints.getMaxVelocityMps());
    assertEquals(2, state.constraints.getMaxAccelerationMpsSq());
    assertEquals(3, state.constraints.getMaxAngularVelocityRps());
    assertEquals(4, state.constraints.getMaxAngularAccelerationRpsSq());
  }
}
