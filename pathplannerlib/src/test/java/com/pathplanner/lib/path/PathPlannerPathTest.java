package com.pathplanner.lib.path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

public class PathPlannerPathTest {
  private static final double EPSILON = 1e-6;

  @Test
  public void testDifferentialStartingPose() {
    PathPlannerPath path =
        new PathPlannerPath(
            List.of(
                new Translation2d(2, 1),
                new Translation2d(3.12, 1),
                new Translation2d(3.67, 1.00),
                new Translation2d(5.19, 1.00)),
            new ArrayList<>(),
            new ArrayList<>(),
            new ArrayList<>(),
            new PathConstraints(1, 2, 3, 4),
            new GoalEndState(0, Rotation2d.fromDegrees(0)),
            true,
            null);

    Pose2d initialPose = path.getStartingDifferentialPose();
    assertNotNull(initialPose);
    assertEquals(2, initialPose.getX(), EPSILON);
    assertEquals(1, initialPose.getY(), EPSILON);
    assertEquals(180, initialPose.getRotation().getDegrees(), EPSILON);
  }

  @Test
  public void testHolomonicStartingPoseSet() {
    PathPlannerPath path =
        new PathPlannerPath(
            List.of(
                new Translation2d(2, 1),
                new Translation2d(3.12, 1),
                new Translation2d(3.67, 1.00),
                new Translation2d(5.19, 1.00)),
            new ArrayList<>(),
            new ArrayList<>(),
            new ArrayList<>(),
            new PathConstraints(1, 2, 3, 4),
            new GoalEndState(0, Rotation2d.fromDegrees(0)),
            true,
            Rotation2d.fromDegrees(90));
    Pose2d initialPose = path.getPreviewStartingHolonomicPose();
    assertNotNull(initialPose);
    assertEquals(2, initialPose.getX(), EPSILON);
    assertEquals(1, initialPose.getY(), EPSILON);
    assertEquals(90, initialPose.getRotation().getDegrees(), EPSILON);
  }

  @Test
  public void testHolomonicStartingPoseNotSet() {
    PathPlannerPath path =
        new PathPlannerPath(
            List.of(
                new Translation2d(2, 1),
                new Translation2d(3.12, 1),
                new Translation2d(3.67, 1.00),
                new Translation2d(5.19, 1.00)),
            new ArrayList<>(),
            new ArrayList<>(),
            new ArrayList<>(),
            new PathConstraints(1, 2, 3, 4),
            new GoalEndState(0, Rotation2d.fromDegrees(0)),
            true,
            null);
    Pose2d initialPose = path.getPreviewStartingHolonomicPose();
    assertNotNull(initialPose);
    assertEquals(2, initialPose.getX(), EPSILON);
    assertEquals(1, initialPose.getY(), EPSILON);
    assertEquals(0, initialPose.getRotation().getDegrees(), EPSILON);
  }
}
