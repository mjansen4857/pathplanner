package com.pathplanner.lib.path;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.wpilib.math.geometry.Rotation2d;
import org.wpilib.math.geometry.Translation2d;

public class PathPlannerPathTest {
  private PathPlannerPath pathWithEndPoint(Translation2d endPoint) {
    return PathPlannerPath.fromPathPoints(
        List.of(new PathPoint(Translation2d.ZERO), new PathPoint(endPoint)),
        new PathConstraints(1.0, 2.0, 3.0, 4.0),
        new GoalEndState(0.0, Rotation2d.ZERO));
  }

  @Test
  public void initialHeadingUsesDirectionOfFirstSegment() {
    assertEquals(
        90.0, pathWithEndPoint(new Translation2d(0.0, 1.0)).getInitialHeading().getDegrees(), 1e-9);
  }

  @Test
  public void initialHeadingIsZeroForCoincidentPoints() {
    assertEquals(Rotation2d.ZERO, pathWithEndPoint(Translation2d.ZERO).getInitialHeading());
  }
}
