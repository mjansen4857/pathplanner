package com.pathplanner.lib.commands;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import com.pathplanner.lib.trajectory.PathPlannerTrajectoryState;
import com.pathplanner.lib.util.DriveFeedforwards;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Tests focus on the projection geometry exercised by FollowPathDistanceCommand. The {@code
 * projectOntoPath} / {@code scanWindow} machinery is exercised indirectly by constructing known
 * trajectories and asserting that {@link PathPlannerTrajectory#sampleByDistance(double)} at the
 * projected s lands where expected.
 *
 * <p>End-to-end command lifecycle (initialize/execute/end) needs a full RobotConfig and a real
 * subsystem, so it's covered in sim/integration testing rather than unit tests.
 */
public class FollowPathDistanceCommandTest {

  private static PathPlannerTrajectory straightLineX(double length) {
    int samples = (int) Math.round(length / 0.05);
    List<PathPlannerTrajectoryState> states = new ArrayList<>();
    double step = length / samples;
    for (int i = 0; i <= samples; i++) {
      double x = i * step;
      var s = new PathPlannerTrajectoryState();
      s.timeSeconds = x / 1.0;
      s.pose = new Pose2d(new Translation2d(x, 0), Rotation2d.kZero);
      s.heading = Rotation2d.kZero;
      s.linearVelocity = 1.0;
      s.fieldSpeeds = new ChassisSpeeds(1.0, 0, 0);
      s.feedforwards = DriveFeedforwards.zeros(4);
      states.add(s);
    }
    return new PathPlannerTrajectory(states);
  }

  // Tests call the real FollowPathDistanceCommand.scanWindow (package-private static), so any
  // future change to the algorithm is reflected here. End-to-end command lifecycle
  // (initialize/execute/end) needs a full RobotConfig and a real subsystem, so it's covered in
  // sim/integration testing rather than unit tests.

  @Test
  public void projectsExactlyOntoStraightPathAtKnownStates() {
    var traj = straightLineX(2.0);
    var states = traj.getStates();
    for (int i = 0; i < states.size(); i++) {
      var pos = states.get(i).pose.getTranslation();
      var r = FollowPathDistanceCommand.scanWindow(pos, states, 0, states.size() - 2);
      assertEquals(states.get(i).distanceAlongPath, r.arcLength, 1e-9, "state " + i);
      assertEquals(0.0, r.distance, 1e-9);
    }
  }

  @Test
  public void projectsPerpendicularOffsetOntoNearestPathPoint() {
    var traj = straightLineX(2.0);
    var states = traj.getStates();
    // Robot at (0.5, 0.3) on a path along +X: closest point is (0.5, 0), s=0.5, dist=0.3
    var r =
        FollowPathDistanceCommand.scanWindow(
            new Translation2d(0.5, 0.3), states, 0, states.size() - 2);
    assertEquals(0.5, r.arcLength, 1e-9);
    assertEquals(0.3, r.distance, 1e-9);
  }

  @Test
  public void projectsRobotAheadOfPathEndClampsToEndState() {
    var traj = straightLineX(2.0);
    var states = traj.getStates();
    // Robot at (3.0, 0) -- past the path's end at (2.0, 0). The closest segment is the last,
    // and u clamps to 1.0, giving s=totalArcLength.
    var r =
        FollowPathDistanceCommand.scanWindow(
            new Translation2d(3.0, 0), states, 0, states.size() - 2);
    assertEquals(traj.getTotalArcLength(), r.arcLength, 1e-9);
  }

  @Test
  public void projectsRobotBehindPathStartClampsToInitialState() {
    var traj = straightLineX(2.0);
    var states = traj.getStates();
    // Robot at (-1.0, 0) -- before path start. Best segment is the first, u clamps to 0.
    var r =
        FollowPathDistanceCommand.scanWindow(
            new Translation2d(-1.0, 0), states, 0, states.size() - 2);
    assertEquals(0.0, r.arcLength, 1e-9);
  }

  @Test
  public void projectionWithinWindowDoesntCrossWholePath() {
    var traj = straightLineX(2.0);
    var states = traj.getStates();
    // Lookahead window [5, 10]. Robot truly closest to state 20 at (1.0, 0) -- but window scan
    // returns the best within [5, 10]. Demonstrates that the window limits results -- the full
    // algorithm has a saturation-fallback (tested separately) to handle this.
    var r = FollowPathDistanceCommand.scanWindow(new Translation2d(1.0, 0), states, 5, 10);
    assertTrue(r.segmentIndex >= 5 && r.segmentIndex <= 10);
    // The closest in-window point is the end of segment 10 (state 11 at s~=0.55).
    assertTrue(r.arcLength <= 0.55 + 1e-6);
  }

  @Test
  public void sampleByDistanceAtProjectedSGivesTargetPoseOnPath() {
    var traj = straightLineX(2.0);
    var states = traj.getStates();
    // Robot at (1.234, 0.5) -- 1.234 along path, 0.5 m off. Sampling at projected s should
    // return a state on the path at x=1.234 (sub-mm) on a straight constant-speed path.
    var r =
        FollowPathDistanceCommand.scanWindow(
            new Translation2d(1.234, 0.5), states, 0, states.size() - 2);
    var target = traj.sampleByDistance(r.arcLength);
    assertEquals(1.234, target.pose.getX(), 1e-6);
    assertEquals(0.0, target.pose.getY(), 1e-9);
  }

  @Test
  public void endConditionsDefaultsHasSensibleValues() {
    var ec = FollowPathDistanceCommand.EndConditions.defaults();
    assertEquals(0.05, ec.distanceToleranceMeters(), 1e-9);
    assertEquals(0.1, ec.velocityToleranceMPS(), 1e-9);
    assertEquals(Math.toRadians(5.0), ec.rotationToleranceRad(), 1e-9);
  }

  @Test
  public void endConditionsCustomValuesArePreserved() {
    var ec = new FollowPathDistanceCommand.EndConditions(0.10, 0.2, Math.toRadians(10.0));
    assertEquals(0.10, ec.distanceToleranceMeters(), 1e-9);
    assertEquals(0.2, ec.velocityToleranceMPS(), 1e-9);
    assertEquals(Math.toRadians(10.0), ec.rotationToleranceRad(), 1e-9);
  }

  @Test
  public void endConditionsRotationCanBeDisabled() {
    var ec = new FollowPathDistanceCommand.EndConditions(0.05, 0.1, Double.POSITIVE_INFINITY);
    assertNotNull(ec);
    assertEquals(Double.POSITIVE_INFINITY, ec.rotationToleranceRad());
  }
}
