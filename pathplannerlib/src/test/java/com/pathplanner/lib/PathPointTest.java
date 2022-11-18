package com.pathplanner.lib;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import org.junit.jupiter.api.Test;

public class PathPointTest {
  public static final double DELTA = 1e-2;

  @Test
  public void constructor() {
    PathPoint p =
        new PathPoint(
            new Translation2d(1.2, 2.7),
            Rotation2d.fromDegrees(25),
            Rotation2d.fromDegrees(67),
            2.4);

    assertEquals(new Translation2d(1.2, 2.7), p.position);
    assertEquals(Rotation2d.fromDegrees(25), p.heading);
    assertEquals(Rotation2d.fromDegrees(67), p.holonomicRotation);
    assertEquals(2.4, p.velocityOverride, DELTA);
  }

  @Test
  public void fromCurrentHolonomicState() {
    Pose2d pose = new Pose2d(1.7, 2.1, Rotation2d.fromDegrees(45));
    ChassisSpeeds speeds = new ChassisSpeeds(1.7, -1.2, 0.8);

    PathPoint p = PathPoint.fromCurrentHolonomicState(pose, speeds);
    assertEquals(new Translation2d(1.7, 2.1), p.position);
    assertEquals(-35.22, p.heading.getDegrees(), DELTA);
    assertEquals(45, p.holonomicRotation.getDegrees(), DELTA);
    assertEquals(2.08, p.velocityOverride, DELTA);
  }

  @Test
  public void fromCurrentDifferentialState() {
    Pose2d pose = new Pose2d(1.7, 2.1, Rotation2d.fromDegrees(45));
    ChassisSpeeds speeds = new ChassisSpeeds(1.7, 0.0, 0.8);

    PathPoint p = PathPoint.fromCurrentDifferentialState(pose, speeds);
    assertEquals(new Translation2d(1.7, 2.1), p.position);
    assertEquals(45.0, p.heading.getDegrees(), DELTA);
    assertEquals(0.0, p.holonomicRotation.getDegrees(), DELTA);
    assertEquals(1.7, p.velocityOverride, DELTA);
  }
}
