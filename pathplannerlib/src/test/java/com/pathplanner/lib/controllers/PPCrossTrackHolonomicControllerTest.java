package com.pathplanner.lib.controllers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.pathplanner.lib.config.PIDConstants;
import com.pathplanner.lib.trajectory.PathPlannerTrajectoryState;
import com.pathplanner.lib.util.DriveFeedforwards;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import org.junit.jupiter.api.Test;

public class PPCrossTrackHolonomicControllerTest {
  private static final double DELTA = 1e-6;

  private static PathPlannerTrajectoryState targetAt(double x, double y, double headingRad) {
    var s = new PathPlannerTrajectoryState();
    s.pose = new Pose2d(new Translation2d(x, y), Rotation2d.fromRadians(headingRad));
    s.heading = Rotation2d.fromRadians(headingRad);
    s.linearVelocity = 2.0;
    s.fieldSpeeds = new ChassisSpeeds(2.0 * Math.cos(headingRad), 2.0 * Math.sin(headingRad), 0.0);
    s.feedforwards = DriveFeedforwards.zeros(4);
    return s;
  }

  @Test
  public void zeroErrorReturnsFeedforwardOnly() {
    var controller =
        new PPCrossTrackHolonomicController(
            new PIDConstants(3.0, 0.0, 0.5), new PIDConstants(5.0, 0.0, 0.0), 0.0);
    var target = targetAt(1.0, 0.0, 0.0); // path going +X at (1,0)
    var pose = new Pose2d(new Translation2d(1.0, 0.0), Rotation2d.kZero); // robot at target
    var speeds = controller.calculateRobotRelativeSpeeds(pose, target);
    // Robot-frame speeds when heading=0 == field speeds
    assertEquals(2.0, speeds.vxMetersPerSecond, DELTA);
    assertEquals(0.0, speeds.vyMetersPerSecond, DELTA);
    assertEquals(0.0, speeds.omegaRadiansPerSecond, DELTA);
  }

  @Test
  public void positiveCrossTrackErrorProducesPerpendicularCorrection() {
    var controller =
        new PPCrossTrackHolonomicController(
            new PIDConstants(3.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0), 0.0);
    // Path going +X, target at origin, robot 0.1 m to the LEFT (+Y).
    var target = targetAt(0.0, 0.0, 0.0);
    var pose = new Pose2d(new Translation2d(0.0, 0.1), Rotation2d.kZero);
    var speeds = controller.calculateRobotRelativeSpeeds(pose, target);
    // Cross-track error should push robot back toward path (-Y direction).
    // With kp=3.0, perpVelocity = -(3.0 * 0.1) = -0.3 m/s along the +Y direction.
    // Plus tangent FF of 2.0 along +X.
    assertEquals(2.0, speeds.vxMetersPerSecond, DELTA);
    assertEquals(-0.3, speeds.vyMetersPerSecond, DELTA);
  }

  @Test
  public void negativeCrossTrackErrorProducesPositivePerpendicularCorrection() {
    var controller =
        new PPCrossTrackHolonomicController(
            new PIDConstants(3.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0), 0.0);
    // Path going +X, robot to the RIGHT (-Y).
    var target = targetAt(0.0, 0.0, 0.0);
    var pose = new Pose2d(new Translation2d(0.0, -0.1), Rotation2d.kZero);
    var speeds = controller.calculateRobotRelativeSpeeds(pose, target);
    assertEquals(2.0, speeds.vxMetersPerSecond, DELTA);
    assertEquals(0.3, speeds.vyMetersPerSecond, DELTA);
  }

  @Test
  public void tangentDirectionErrorProducesNoPerpendicularCorrection() {
    var controller =
        new PPCrossTrackHolonomicController(
            new PIDConstants(3.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0), 0.0);
    // Path going +X, robot AHEAD of target along the tangent (no cross-track error).
    var target = targetAt(0.0, 0.0, 0.0);
    var pose = new Pose2d(new Translation2d(0.5, 0.0), Rotation2d.kZero);
    var speeds = controller.calculateRobotRelativeSpeeds(pose, target);
    // Tangent-direction error doesn't affect cross-track; output is pure feedforward.
    assertEquals(2.0, speeds.vxMetersPerSecond, DELTA);
    assertEquals(0.0, speeds.vyMetersPerSecond, DELTA);
  }

  @Test
  public void curvatureFfAddsCentripetalPerpendicularVelocity() {
    var controller =
        new PPCrossTrackHolonomicController(
            new PIDConstants(0.0, 0.0, 0.0), // disable cross-track to isolate FF
            new PIDConstants(5.0, 0.0, 0.0),
            0.1); // FF gain
    // Target with left-curving path: kappa = +0.5 (1/m), v = 2.0 m/s
    // curvatureFf = 0.1 * 2.0^2 * 0.5 = 0.2 m/s perpendicular (toward inside of curve, +Y).
    var target = targetAt(0.0, 0.0, 0.0);
    target.curvatureRadPerMeter = 0.5;
    var pose = new Pose2d(new Translation2d(0.0, 0.0), Rotation2d.kZero);
    var speeds = controller.calculateRobotRelativeSpeeds(pose, target);
    assertEquals(2.0, speeds.vxMetersPerSecond, DELTA);
    assertEquals(0.2, speeds.vyMetersPerSecond, DELTA);
  }

  @Test
  public void curvatureFfSignFlipsForRightCurve() {
    var controller =
        new PPCrossTrackHolonomicController(
            new PIDConstants(0.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0), 0.1);
    var target = targetAt(0.0, 0.0, 0.0);
    target.curvatureRadPerMeter = -0.5; // right turn
    var pose = new Pose2d(new Translation2d(0.0, 0.0), Rotation2d.kZero);
    var speeds = controller.calculateRobotRelativeSpeeds(pose, target);
    assertEquals(2.0, speeds.vxMetersPerSecond, DELTA);
    assertEquals(-0.2, speeds.vyMetersPerSecond, DELTA);
  }

  @Test
  public void headingErrorProducesRotationFeedback() {
    var controller =
        new PPCrossTrackHolonomicController(
            new PIDConstants(0.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0), 0.0);
    var target = targetAt(0.0, 0.0, 0.0); // target rotation = 0
    // Robot rotated 10 degrees right (-Z, negative): heading error pulls it back +Z.
    var pose = new Pose2d(new Translation2d(0.0, 0.0), Rotation2d.fromDegrees(-10.0));
    var speeds = controller.calculateRobotRelativeSpeeds(pose, target);
    // kp=5.0, error = +10 deg = +0.1745 rad, expected omega = 5 * 0.1745 ~= 0.872 rad/s positive
    assertTrue(speeds.omegaRadiansPerSecond > 0.5);
    assertTrue(speeds.omegaRadiansPerSecond < 1.2);
  }

  @Test
  public void defaultsFactoryProducesNonNullController() {
    var c = PPCrossTrackHolonomicController.defaults();
    var target = targetAt(0.0, 0.0, 0.0);
    var pose = new Pose2d(new Translation2d(0.0, 0.1), Rotation2d.kZero);
    var speeds = c.calculateRobotRelativeSpeeds(pose, target);
    // Just confirm it produces *some* perpendicular correction with default gains
    assertTrue(
        speeds.vyMetersPerSecond < 0,
        "default gains should pull robot back toward path (negative y for +y error)");
  }

  @Test
  public void isHolonomicReturnsTrue() {
    var c = PPCrossTrackHolonomicController.defaults();
    assertTrue(c.isHolonomic());
  }

  @Test
  public void resetClearsCrossTrackDerivativeState() {
    // Pure D, period 0.02s: D output = (e_n - e_{n-1}) / 0.02, applied with sign such that vy
    // pushes back toward path (i.e. for rising +y error, vy goes -y).
    var controller =
        new PPCrossTrackHolonomicController(
            new PIDConstants(0.0, 0.0, 1.0), new PIDConstants(0.0, 0.0, 0.0), 0.0);
    var target = targetAt(0.0, 0.0, 0.0);

    // 1st call: hasLastError=false guard returns 0 regardless of error.
    var first =
        controller.calculateRobotRelativeSpeeds(
            new Pose2d(new Translation2d(0, 0.0), Rotation2d.kZero), target);
    assertEquals(0.0, first.vyMetersPerSecond, DELTA);

    // 2nd call: error jumps from 0.0 to 0.2 over one period (0.02s). D term observes the
    // change: rate = (0.2 - 0.0) / 0.02 = 10.0, correction = -kd * rate = -10 in the +y normal
    // direction, so vy = -10.
    var second =
        controller.calculateRobotRelativeSpeeds(
            new Pose2d(new Translation2d(0, 0.2), Rotation2d.kZero), target);
    assertEquals(
        -10.0,
        second.vyMetersPerSecond,
        1e-6,
        "second call should see D-term reflecting the 0.0->0.2 step");

    // Reset clears the error history. The next call with err=0.2 is again the "first call":
    // hasLastError=false guard returns D=0, NOT -10 (which would indicate stale state).
    controller.reset(Pose2d.kZero, new ChassisSpeeds());
    var afterReset =
        controller.calculateRobotRelativeSpeeds(
            new Pose2d(new Translation2d(0, 0.2), Rotation2d.kZero), target);
    assertEquals(
        0.0,
        afterReset.vyMetersPerSecond,
        DELTA,
        "after reset, first call must suppress D regardless of error magnitude");
  }
}
