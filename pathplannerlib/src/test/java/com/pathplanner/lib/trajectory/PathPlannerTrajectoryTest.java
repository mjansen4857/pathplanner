package com.pathplanner.lib.trajectory;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.pathplanner.lib.util.DriveFeedforwards;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

public class PathPlannerTrajectoryTest {
  private static final double DELTA = 1e-6;

  /**
   * Build a synthetic trajectory along a quarter-circle of radius R from (R, 0) heading +Y to (0,
   * R) heading -X. Samples are uniform in path-parameter theta. Timestamps are derived from the
   * chord-summed arc length so time and distance are proportional (allowing time-vs-distance
   * sampling comparisons on this curved path).
   */
  private static PathPlannerTrajectory quarterArc(double radius, double linearVel) {
    double arcLength = radius * Math.PI / 2.0;
    int samples = (int) Math.round(arcLength / 0.05);
    List<PathPlannerTrajectoryState> states = new ArrayList<>();
    double cumChord = 0.0;
    double prevX = radius;
    double prevY = 0.0;
    for (int i = 0; i <= samples; i++) {
      double theta = (Math.PI / 2.0) * (i / (double) samples);
      double x = radius * Math.cos(theta);
      double y = radius * Math.sin(theta);
      if (i > 0) cumChord += Math.hypot(x - prevX, y - prevY);
      Rotation2d heading = Rotation2d.fromRadians(theta + Math.PI / 2.0);
      var s = new PathPlannerTrajectoryState();
      s.timeSeconds = cumChord / linearVel;
      s.pose = new Pose2d(x, y, Rotation2d.kZero);
      s.linearVelocity = linearVel;
      s.heading = heading;
      s.fieldSpeeds =
          new ChassisSpeeds(linearVel * heading.getCos(), linearVel * heading.getSin(), 0.0);
      s.feedforwards = DriveFeedforwards.zeros(4);
      states.add(s);
      prevX = x;
      prevY = y;
    }
    return new PathPlannerTrajectory(states);
  }

  /** Build a synthetic straight-line trajectory from origin along +X at constant speed. */
  private static PathPlannerTrajectory straightLine(double length, double linearVel) {
    int samples = (int) Math.round(length / 0.05);
    List<PathPlannerTrajectoryState> states = new ArrayList<>();
    double step = length / samples;
    for (int i = 0; i <= samples; i++) {
      double x = i * step;
      var s = new PathPlannerTrajectoryState();
      s.timeSeconds = x / linearVel;
      s.pose = new Pose2d(x, 0, Rotation2d.kZero);
      s.linearVelocity = linearVel;
      s.heading = Rotation2d.kZero;
      s.fieldSpeeds = new ChassisSpeeds(linearVel, 0, 0);
      s.feedforwards = DriveFeedforwards.zeros(4);
      states.add(s);
    }
    return new PathPlannerTrajectory(states);
  }

  @Test
  public void populatesDistanceAlongPathCumulatively() {
    var traj = quarterArc(1.0, 1.0);
    assertEquals(0.0, traj.getInitialState().distanceAlongPath, DELTA);
    // Each consecutive chord on the unit quarter-circle is < 0.05 m (chord < arc); confirm
    // monotonic increase and last state matches sum of all segments.
    double expected = 0.0;
    var states = traj.getStates();
    for (int i = 1; i < states.size(); i++) {
      double seg =
          states.get(i).pose.getTranslation().getDistance(states.get(i - 1).pose.getTranslation());
      expected += seg;
      assertEquals(expected, states.get(i).distanceAlongPath, DELTA);
      assertTrue(states.get(i).distanceAlongPath > states.get(i - 1).distanceAlongPath);
    }
    assertEquals(expected, traj.getTotalArcLength(), DELTA);
  }

  @Test
  public void getTotalArcLengthApproachesGeometricArcAsSamplingDensityIncreases() {
    // Chord-summed length under-estimates the true arc length. For the quarter-circle of
    // radius 1, the geometric arc is pi/2 ~= 1.5708. With ~31 samples (0.05 m spacing on a
    // ~1.57 m arc), the chord sum should be within 0.1% of the true arc.
    var traj = quarterArc(1.0, 1.0);
    double geometricArc = Math.PI / 2.0;
    assertEquals(geometricArc, traj.getTotalArcLength(), 1e-3);
  }

  @Test
  public void sampleByDistanceClampsBelowZero() {
    var traj = quarterArc(1.0, 1.0);
    assertSame(traj.getInitialState(), traj.sampleByDistance(-1.0));
    assertSame(traj.getInitialState(), traj.sampleByDistance(0.0));
  }

  @Test
  public void sampleByDistanceClampsAboveEnd() {
    var traj = quarterArc(1.0, 1.0);
    double total = traj.getTotalArcLength();
    assertSame(traj.getEndState(), traj.sampleByDistance(total));
    assertSame(traj.getEndState(), traj.sampleByDistance(total + 1.0));
  }

  @Test
  public void sampleByDistanceReturnsDistanceAlongPathExactly() {
    // distanceAlongPath is a pure lerp of the bracket values.
    var traj = quarterArc(1.0, 1.0);
    for (var state : traj.getStates()) {
      var sampled = traj.sampleByDistance(state.distanceAlongPath);
      assertEquals(state.distanceAlongPath, sampled.distanceAlongPath, 1e-9);
    }
  }

  @Test
  public void interpolateAtT1ReturnsEndPose() {
    // Regression: pre-fix interpolate's loop started at timeSeconds + 0.01 and used the start
    // state's heading throughout, so even at t=1 the pose was 1 0.01 s step short of endVal.
    // With the fix, interpolate(s0, s1, 1.0) should reproduce s1.pose to sub-mm.
    var traj = straightLine(2.0, 1.0);
    var states = traj.getStates();
    var a = states.get(10);
    var b = states.get(11);
    var lerped = a.interpolate(b, 1.0);
    assertEquals(b.pose.getX(), lerped.pose.getX(), 1e-9);
    assertEquals(b.pose.getY(), lerped.pose.getY(), 1e-9);
  }

  @Test
  public void interpolateAtT0ReturnsStartPose() {
    var traj = straightLine(2.0, 1.0);
    var states = traj.getStates();
    var a = states.get(10);
    var b = states.get(11);
    var lerped = a.interpolate(b, 0.0);
    assertEquals(a.pose.getX(), lerped.pose.getX(), 1e-9);
    assertEquals(a.pose.getY(), lerped.pose.getY(), 1e-9);
  }

  @Test
  public void interpolateAtMidpointGivesGeometricMidpointOnStraightLine() {
    var traj = straightLine(2.0, 1.0);
    var states = traj.getStates();
    var a = states.get(10); // x = 0.5
    var b = states.get(11); // x = 0.55
    var mid = a.interpolate(b, 0.5);
    assertEquals(0.525, mid.pose.getX(), 1e-9);
    assertEquals(0.0, mid.pose.getY(), 1e-9);
  }

  @Test
  public void interpolateWithZeroDeltaTReturnsCopyOfStart() {
    // Regression: pre-fix code divided by zero in intT = (intTime - timeSeconds) / deltaT,
    // producing NaN pose. With the fix the integration is skipped when deltaT == 0.
    var s0 = new PathPlannerTrajectoryState();
    s0.timeSeconds = 1.0;
    s0.pose = new Pose2d(new Translation2d(3.0, 4.0), Rotation2d.kZero);
    s0.heading = Rotation2d.kZero;
    s0.linearVelocity = 2.0;
    s0.fieldSpeeds = new ChassisSpeeds(2.0, 0, 0);
    s0.feedforwards = DriveFeedforwards.zeros(4);
    var s1 = new PathPlannerTrajectoryState();
    s1.timeSeconds = 1.0; // same time as s0
    s1.pose = new Pose2d(new Translation2d(3.5, 4.0), Rotation2d.kZero);
    s1.heading = Rotation2d.kZero;
    s1.linearVelocity = 2.0;
    s1.fieldSpeeds = new ChassisSpeeds(2.0, 0, 0);
    s1.feedforwards = DriveFeedforwards.zeros(4);
    var lerped = s0.interpolate(s1, 0.5);
    assertTrue(Double.isFinite(lerped.pose.getX()), "deltaT=0 must not produce NaN");
    assertTrue(Double.isFinite(lerped.pose.getY()), "deltaT=0 must not produce NaN");
    assertEquals(s0.pose.getX(), lerped.pose.getX(), 1e-9);
    assertEquals(s0.pose.getY(), lerped.pose.getY(), 1e-9);
  }

  @Test
  public void interpolateWithSmallDeltaTIntegratesForward() {
    // Regression: pre-fix code with deltaT < 0.01 entered the break case immediately with
    // dt = lerpedState.timeSeconds - intTime = NEGATIVE, integrating BACKWARDS. With the fix,
    // deltaT = 0.005 integrates v * 0.005 = 0.005 of forward motion.
    var s0 = new PathPlannerTrajectoryState();
    s0.timeSeconds = 0.0;
    s0.pose = new Pose2d(new Translation2d(0.0, 0.0), Rotation2d.kZero);
    s0.heading = Rotation2d.kZero;
    s0.linearVelocity = 1.0;
    s0.fieldSpeeds = new ChassisSpeeds(1.0, 0, 0);
    s0.feedforwards = DriveFeedforwards.zeros(4);
    var s1 = new PathPlannerTrajectoryState();
    s1.timeSeconds = 0.005;
    s1.pose = new Pose2d(new Translation2d(0.005, 0.0), Rotation2d.kZero);
    s1.heading = Rotation2d.kZero;
    s1.linearVelocity = 1.0;
    s1.fieldSpeeds = new ChassisSpeeds(1.0, 0, 0);
    s1.feedforwards = DriveFeedforwards.zeros(4);
    var lerped = s0.interpolate(s1, 1.0);
    // Forward motion expected: 1.0 m/s * 0.005 s = 0.005 m
    assertEquals(0.005, lerped.pose.getX(), 1e-9);
    assertEquals(0.0, lerped.pose.getY(), 1e-9);
  }

  @Test
  public void sampleByDistanceInterpolatesBetweenStates() {
    // Halfway between two adjacent states should land near (not at) either endpoint, and on
    // a quarter-circle, near the midpoint chord.
    var traj = quarterArc(1.0, 1.0);
    var states = traj.getStates();
    var a = states.get(5);
    var b = states.get(6);
    double midS = (a.distanceAlongPath + b.distanceAlongPath) / 2.0;
    var mid = traj.sampleByDistance(midS);
    // distanceAlongPath itself is lerped exactly
    assertEquals(midS, mid.distanceAlongPath, DELTA);
    // Sampled pose should sit strictly between the bracket poses (not equal to either)
    double dxA = mid.pose.getX() - a.pose.getX();
    double dxB = b.pose.getX() - mid.pose.getX();
    assertTrue(
        Math.signum(dxA) == Math.signum(dxB) || dxA == 0 || dxB == 0,
        "midpoint should advance monotonically between bracket states");
  }

  @Test
  public void sampleByDistanceAgreesWithSampleByTimeOnStraightLine() {
    // On a constant-speed straight line, t and s are exactly proportional; sample(t) and
    // sampleByDistance(v*t) must produce identical poses.
    double v = 1.5;
    var traj = straightLine(2.0, v);
    double totalT = traj.getTotalTimeSeconds();
    for (double t = 0; t <= totalT; t += 0.07) {
      var byTime = traj.sample(t);
      var byDist = traj.sampleByDistance(v * t);
      assertEquals(byTime.pose.getX(), byDist.pose.getX(), 1e-9, "pose-X mismatch at t=" + t);
      assertEquals(byTime.pose.getY(), byDist.pose.getY(), 1e-9, "pose-Y mismatch at t=" + t);
    }
  }

  @Test
  public void sampleByDistanceAgreesWithSampleByTimeOnArc() {
    // On the quarter-arc (timestamps derived from cumulative chord length so t and s are
    // proportional at every state), the two samplers should agree within sub-mm at any query.
    double v = 1.0;
    var traj = quarterArc(1.0, v);
    double totalT = traj.getTotalTimeSeconds();
    for (double t = 0; t <= totalT; t += 0.05) {
      var byTime = traj.sample(t);
      var byDist = traj.sampleByDistance(v * t);
      assertEquals(byTime.pose.getX(), byDist.pose.getX(), 1e-3, "pose-X mismatch at t=" + t);
      assertEquals(byTime.pose.getY(), byDist.pose.getY(), 1e-3, "pose-Y mismatch at t=" + t);
    }
  }

  @Test
  public void distanceAlongPathSurvivesFlip() {
    var traj = quarterArc(1.0, 1.0);
    double totalBefore = traj.getTotalArcLength();
    var flipped = traj.flip();
    // flipped() rebuilds states via the (states, events) constructor which re-populates
    // distanceAlongPath from pose distances. After flipping (rotate 180 + translate to mirror
    // field), pose-to-pose distances are preserved, so total arc length must match.
    assertEquals(totalBefore, flipped.getTotalArcLength(), DELTA);
  }

  @Test
  public void copyWithTimePreservesDistanceAlongPath() {
    var traj = quarterArc(1.0, 1.0);
    var state = traj.getState(5);
    var copy = state.copyWithTime(42.0);
    assertEquals(state.distanceAlongPath, copy.distanceAlongPath, DELTA);
    assertEquals(42.0, copy.timeSeconds, DELTA);
  }

  @Test
  public void curvaturePopulatedOnStraightLineIsZero() {
    var traj = straightLine(2.0, 1.0);
    for (var state : traj.getStates()) {
      assertEquals(0.0, state.curvatureRadPerMeter, 1e-9);
    }
  }

  @Test
  public void curvaturePopulatedOnQuarterArcMatchesReciprocalRadius() {
    // Unit circle -> kappa = 1.0 (1/m). Positive sign because the arc goes CCW (left turn).
    var traj = quarterArc(1.0, 1.0);
    // Interior states (skip endpoints which get 0).
    var states = traj.getStates();
    for (int i = 1; i < states.size() - 1; i++) {
      // Allow some tolerance because three-point circle fit on a sampled arc has small error.
      assertEquals(
          1.0, states.get(i).curvatureRadPerMeter, 0.05, "expected curvature ~1.0 at state " + i);
      assertTrue(
          states.get(i).curvatureRadPerMeter > 0,
          "left-turning arc should have positive curvature at state " + i);
    }
  }

  @Test
  public void curvatureEndpointsAreZero() {
    var traj = quarterArc(1.0, 1.0);
    var states = traj.getStates();
    assertEquals(0.0, states.get(0).curvatureRadPerMeter, 1e-9);
    assertEquals(0.0, states.get(states.size() - 1).curvatureRadPerMeter, 1e-9);
  }

  @Test
  public void interpolatePreservesCurvatureLinearly() {
    var s0 = new PathPlannerTrajectoryState();
    s0.timeSeconds = 0;
    s0.pose = Pose2d.kZero;
    s0.heading = Rotation2d.kZero;
    s0.linearVelocity = 1.0;
    s0.fieldSpeeds = new ChassisSpeeds(1.0, 0, 0);
    s0.feedforwards = DriveFeedforwards.zeros(4);
    s0.curvatureRadPerMeter = 0.0;

    var s1 = new PathPlannerTrajectoryState();
    s1.timeSeconds = 1.0;
    s1.pose = new Pose2d(new Translation2d(1.0, 0), Rotation2d.kZero);
    s1.heading = Rotation2d.kZero;
    s1.linearVelocity = 1.0;
    s1.fieldSpeeds = new ChassisSpeeds(1.0, 0, 0);
    s1.feedforwards = DriveFeedforwards.zeros(4);
    s1.curvatureRadPerMeter = 2.0;

    var mid = s0.interpolate(s1, 0.5);
    assertEquals(1.0, mid.curvatureRadPerMeter, DELTA);
  }

  @Test
  public void interpolatePreservesDistanceAlongPathLinearly() {
    var s0 = new PathPlannerTrajectoryState();
    s0.timeSeconds = 0;
    s0.pose = Pose2d.kZero;
    s0.heading = Rotation2d.kZero;
    s0.linearVelocity = 1.0;
    s0.fieldSpeeds = new ChassisSpeeds(1.0, 0, 0);
    s0.feedforwards = DriveFeedforwards.zeros(4);
    s0.distanceAlongPath = 0.0;

    var s1 = new PathPlannerTrajectoryState();
    s1.timeSeconds = 1.0;
    s1.pose = new Pose2d(new Translation2d(1.0, 0), Rotation2d.kZero);
    s1.heading = Rotation2d.kZero;
    s1.linearVelocity = 1.0;
    s1.fieldSpeeds = new ChassisSpeeds(1.0, 0, 0);
    s1.feedforwards = DriveFeedforwards.zeros(4);
    s1.distanceAlongPath = 1.0;

    var mid = s0.interpolate(s1, 0.5);
    assertEquals(0.5, mid.distanceAlongPath, DELTA);
  }
}
