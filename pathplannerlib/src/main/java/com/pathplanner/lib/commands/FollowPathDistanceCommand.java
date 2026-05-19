package com.pathplanner.lib.commands;

import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.events.EventScheduler;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import com.pathplanner.lib.trajectory.PathPlannerTrajectoryState;
import com.pathplanner.lib.util.DriveFeedforwards;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.function.BiConsumer;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

/**
 * Path-following command that drives by projected arc length instead of elapsed time. On each
 * cycle, the robot's current pose is projected onto the path, the controller is given the target
 * state at that arc length, and the path finishes when the robot has reached the end position (with
 * optional velocity and rotation gates).
 *
 * <p>Useful when a time-based reference would race ahead during disturbances (obstacles, contact
 * with a game piece, momentary slippage). The target state always reflects where the robot actually
 * is on the path, so cross-track error is measured at true progress.
 *
 * <p>Pairs well with {@link com.pathplanner.lib.controllers.PPCrossTrackHolonomicController}.
 */
public class FollowPathDistanceCommand extends Command {
  /**
   * End-of-path tolerances. The command finishes when all three conditions are met:
   *
   * <ul>
   *   <li>Projected arc length is within {@code distanceToleranceMeters} of the path end
   *   <li>Speed component along the path's end tangent is below {@code velocityToleranceMPS}
   *   <li>Heading error from the path's end rotation is below {@code rotationToleranceRad}
   * </ul>
   *
   * <p>If the path's goal end state has a non-zero velocity (handoff to the next path in an auto),
   * the velocity and rotation gates are skipped and only the distance gate applies.
   *
   * @param distanceToleranceMeters Distance from path end, in meters, below which the path is
   *     considered "near end".
   * @param velocityToleranceMPS Maximum allowed speed component along the path's end tangent, in
   *     m/s.
   * @param rotationToleranceRad Maximum allowed heading error from the path's end rotation, in
   *     radians. Set to {@link Double#POSITIVE_INFINITY} to disable the rotation gate.
   */
  public record EndConditions(
      double distanceToleranceMeters, double velocityToleranceMPS, double rotationToleranceRad) {
    /**
     * Default tolerances: 5 cm distance, 0.1 m/s along-tangent velocity, 5 degrees rotation. Tuned
     * for typical FRC swerve scoring positions where small overshoot is unacceptable.
     *
     * @return Default end conditions
     */
    public static EndConditions defaults() {
      return new EndConditions(0.05, 0.1, Math.toRadians(5.0));
    }
  }

  // Closest-point projection window, in state segments (~5 cm each). Wide enough for 50 Hz moves.
  private static final int LOOKAHEAD_SEGMENTS = 6;
  // If the best closest-point distance in the window exceeds this, fall back to a full-path scan.
  private static final double BIG_GAP_THRESHOLD_M = 0.5;
  // Max projection advance per execute(); caps single-frame jumps from odometry spikes.
  private static final double MAX_DELTA_S_PER_TICK = 0.3;

  // Velocity-FF override at planner-stopping samples. At v=0 samples the planned FF, position
  // errors, and curvature FF are all zero, so the controller outputs nothing and the chassis
  // can't leave the sample. When local planned v is below threshold and lookahead v is above,
  // override targetState's velocity FF (linearVelocity + fieldSpeeds) with a blended peek
  // value; pose/heading/curvature stay at the actual projection so position errors remain
  // honest. The dual-check correctly stays off at the true path end (both local and lookahead
  // are low) so the robot is allowed to stop.
  private static final double BOOTSTRAP_LOOKAHEAD_M = 0.30;
  // Threshold below which we override. Derived as sqrt(2 * a * lookahead/N): the velocity at
  // which the post-stop ramp has covered ~lookahead/N meters. N=6 reproduces ~1.0 m/s on a
  // 10 m/s² ramp (the empirically-tuned default) and adapts to higher/lower accel paths.
  private static final double BOOTSTRAP_THRESHOLD_RAMP_DIVISOR = 6.0;

  private final PathPlannerPath originalPath;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final BiConsumer<ChassisSpeeds, DriveFeedforwards> output;
  private final PathFollowingController controller;
  private final RobotConfig robotConfig;
  private final BooleanSupplier shouldFlipPath;
  private final EndConditions endConditions;
  private final EventScheduler eventScheduler;

  private PathPlannerPath path;
  private PathPlannerTrajectory trajectory;
  private double lastProjectedS;
  private int lastProjectedIdx;
  private double bootstrapVelocityThresholdMps;

  /**
   * Construct a distance-based path-following command.
   *
   * @param path Path to follow
   * @param poseSupplier Supplier of the robot's field-relative pose
   * @param speedsSupplier Supplier of robot-relative chassis speeds
   * @param output Output sink for robot-relative chassis speeds + per-module feedforwards
   * @param controller Path-following controller (typically {@link
   *     com.pathplanner.lib.controllers.PPCrossTrackHolonomicController})
   * @param robotConfig Robot configuration
   * @param shouldFlipPath Whether to mirror/rotate the path for the red alliance
   * @param endConditions End-of-path tolerances (use {@link EndConditions#defaults()} for sane
   *     defaults)
   * @param requirements Subsystem requirements, usually just the drive subsystem
   */
  public FollowPathDistanceCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      BiConsumer<ChassisSpeeds, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      EndConditions endConditions,
      Subsystem... requirements) {
    this.originalPath = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = output;
    this.controller = controller;
    this.robotConfig = robotConfig;
    this.shouldFlipPath = shouldFlipPath;
    this.endConditions = endConditions;
    this.eventScheduler = new EventScheduler();

    Set<Subsystem> driveRequirements = Set.of(requirements);
    addRequirements(requirements);
    var eventReqs = EventScheduler.getSchedulerRequirements(this.originalPath);
    if (!Collections.disjoint(driveRequirements, eventReqs)) {
      throw new IllegalArgumentException(
          "Events that are triggered during path following cannot require the drive subsystem");
    }
    addRequirements(eventReqs);

    this.path = this.originalPath;
    Optional<PathPlannerTrajectory> idealTrajectory =
        this.path.getIdealTrajectory(this.robotConfig);
    idealTrajectory.ifPresent(traj -> this.trajectory = traj);
  }

  /**
   * Convenience constructor using {@link EndConditions#defaults()}.
   *
   * @param path Path to follow
   * @param poseSupplier Supplier of the robot's field-relative pose
   * @param speedsSupplier Supplier of robot-relative chassis speeds
   * @param output Output sink for robot-relative chassis speeds + per-module feedforwards
   * @param controller Path-following controller
   * @param robotConfig Robot configuration
   * @param shouldFlipPath Whether to mirror/rotate the path for the red alliance
   * @param requirements Subsystem requirements
   */
  public FollowPathDistanceCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      BiConsumer<ChassisSpeeds, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    this(
        path,
        poseSupplier,
        speedsSupplier,
        output,
        controller,
        robotConfig,
        shouldFlipPath,
        EndConditions.defaults(),
        requirements);
  }

  @Override
  public void initialize() {
    if (shouldFlipPath.getAsBoolean() && !originalPath.preventFlipping) {
      path = originalPath.flipPath();
    } else {
      path = originalPath;
    }

    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();
    controller.reset(currentPose, currentSpeeds);

    double linearVel = Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);
    if (path.getIdealStartingState() != null) {
      boolean idealVelocity =
          Math.abs(linearVel - path.getIdealStartingState().velocityMPS()) <= 0.25;
      boolean idealRotation =
          !robotConfig.isHolonomic
              || Math.abs(
                      currentPose
                          .getRotation()
                          .minus(path.getIdealStartingState().rotation())
                          .getDegrees())
                  <= 30.0;
      if (idealVelocity && idealRotation) {
        trajectory = path.getIdealTrajectory(robotConfig).orElseThrow();
      } else {
        trajectory = path.generateTrajectory(currentSpeeds, currentPose.getRotation(), robotConfig);
      }
    } else {
      trajectory = path.generateTrajectory(currentSpeeds, currentPose.getRotation(), robotConfig);
    }

    PathPlannerLogging.logActivePath(path);
    PPLibTelemetry.setCurrentPath(path);

    // Initial projection: full scan to handle pose starting anywhere on the path.
    var initialProjection = fullScan(currentPose.getTranslation());
    lastProjectedIdx = initialProjection.segmentIndex;
    lastProjectedS = initialProjection.arcLength;

    // Derive the bootstrap velocity threshold from this path's max accel. Clamped so an
    // unlimited-constraint or zero-accel path doesn't produce absurd values.
    double maxAccel = path.getGlobalConstraints().maxAccelerationMPSSq();
    if (!Double.isFinite(maxAccel) || maxAccel <= 0.0) maxAccel = 10.0;
    bootstrapVelocityThresholdMps =
        Math.sqrt(2.0 * maxAccel * BOOTSTRAP_LOOKAHEAD_M / BOOTSTRAP_THRESHOLD_RAMP_DIVISOR);

    eventScheduler.initialize(trajectory);
  }

  @Override
  public void execute() {
    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    Projection p = projectOntoPath(currentPose.getTranslation());
    // Monotonic clamp + max-delta-per-tick guard
    double advancedS = Math.max(lastProjectedS, p.arcLength);
    advancedS = Math.min(advancedS, lastProjectedS + MAX_DELTA_S_PER_TICK);
    lastProjectedS = advancedS;
    lastProjectedIdx = p.segmentIndex;

    double currentVel =
        Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);

    // See BOOTSTRAP_LOOKAHEAD_M for the override rationale.
    PathPlannerTrajectoryState targetState = trajectory.sampleByDistance(lastProjectedS);
    double localV = targetState.linearVelocity;
    if (localV < bootstrapVelocityThresholdMps) {
      double peekS =
          Math.min(lastProjectedS + BOOTSTRAP_LOOKAHEAD_M, trajectory.getTotalArcLength());
      double peekV = trajectory.sampleByDistance(peekS).linearVelocity;
      if (peekV >= bootstrapVelocityThresholdMps) {
        // Blend on localV (not currentVel) so the override tapers with the planned profile
        // and doesn't chase the chassis as it picks up speed against an at-rest plan.
        double blend = 1.0 - localV / bootstrapVelocityThresholdMps;
        double blendedV = localV + (peekV - localV) * blend;
        // Copy before mutating: sampleByDistance can return cached endpoint references.
        targetState = targetState.copyWithTime(targetState.timeSeconds);
        targetState.linearVelocity = blendedV;
        double cosH = targetState.heading.getCos();
        double sinH = targetState.heading.getSin();
        targetState.fieldSpeeds =
            new ChassisSpeeds(
                blendedV * cosH, blendedV * sinH, targetState.fieldSpeeds.omegaRadiansPerSecond);
      }
    }

    ChassisSpeeds targetSpeeds = controller.calculateRobotRelativeSpeeds(currentPose, targetState);

    PPLibTelemetry.setCurrentPose(currentPose);
    PathPlannerLogging.logCurrentPose(currentPose);
    PPLibTelemetry.setTargetPose(targetState.pose);
    PathPlannerLogging.logTargetPose(targetState.pose);
    PPLibTelemetry.setVelocities(
        currentVel,
        targetState.linearVelocity,
        currentSpeeds.omegaRadiansPerSecond,
        targetSpeeds.omegaRadiansPerSecond);

    output.accept(targetSpeeds, targetState.feedforwards);

    // Event scheduling uses path time, derived from the projected state's timestamp.
    eventScheduler.execute(targetState.timeSeconds);
  }

  @Override
  public boolean isFinished() {
    double totalArc = trajectory.getTotalArcLength();
    boolean nearEnd = lastProjectedS >= totalArc - endConditions.distanceToleranceMeters();
    if (!nearEnd) return false;

    // Handoff path (non-zero end velocity): distance gate only, don't wait for full stop.
    if (!isStoppingPath()) return true;

    PathPlannerTrajectoryState endState = trajectory.getEndState();
    ChassisSpeeds fieldSpeeds = speedsToFieldFrame();
    // Total-magnitude gate (not tangent component) so we don't fire while cross-track PD is
    // still closing perpendicular error.
    double totalSpeed = Math.hypot(fieldSpeeds.vxMetersPerSecond, fieldSpeeds.vyMetersPerSecond);
    boolean velocityOk = totalSpeed < endConditions.velocityToleranceMPS();

    double headingErr =
        Math.abs(poseSupplier.get().getRotation().minus(endState.pose.getRotation()).getRadians());
    boolean rotationOk = headingErr <= endConditions.rotationToleranceRad();

    return velocityOk && rotationOk;
  }

  @Override
  public void end(boolean interrupted) {
    if (!interrupted && isStoppingPath()) {
      output.accept(new ChassisSpeeds(), DriveFeedforwards.zeros(robotConfig.numModules));
    }
    PathPlannerLogging.logActivePath(null);
    eventScheduler.end();
  }

  /**
   * Whether the active path ends with the robot effectively stopped (vs. handing off velocity to a
   * subsequent path). Matches the threshold used by {@link FollowPathCommand}.
   */
  private boolean isStoppingPath() {
    return path.getGoalEndState().velocityMPS() < 0.1;
  }

  /**
   * Project the robot's translation onto the path using the cached lookahead window. Falls back to
   * a full-path scan if the window can't find a close-enough match (covers odometry resets or large
   * disturbances).
   */
  private Projection projectOntoPath(Translation2d robotPos) {
    List<PathPlannerTrajectoryState> states = trajectory.getStates();
    int n = states.size();
    if (n < 2) return new Projection(0, 0.0);

    int windowStart = Math.max(0, lastProjectedIdx);
    int windowEnd = Math.min(n - 2, lastProjectedIdx + LOOKAHEAD_SEGMENTS);
    Projection best = scanWindow(robotPos, states, windowStart, windowEnd);

    // Saturated at the forward edge: extend one window to catch fast multi-state moves.
    if (best.segmentIndex == windowEnd && best.segmentU >= 0.99 && windowEnd < n - 2) {
      int extEnd = Math.min(n - 2, windowEnd + LOOKAHEAD_SEGMENTS);
      Projection extended = scanWindow(robotPos, states, windowEnd, extEnd);
      if (extended.distance < best.distance) best = extended;
    }

    // Window match too far: full scan, but only accept it if it's both closer and not backward.
    if (best.distance > BIG_GAP_THRESHOLD_M) {
      Projection fullScan = fullScan(robotPos);
      if (fullScan.distance < best.distance && fullScan.arcLength >= lastProjectedS) {
        best = fullScan;
      }
    }
    return best;
  }

  private Projection fullScan(Translation2d robotPos) {
    List<PathPlannerTrajectoryState> states = trajectory.getStates();
    if (states.size() < 2) return new Projection(0, 0.0);
    return scanWindow(robotPos, states, 0, states.size() - 2);
  }

  /** Closest-point-on-polyline over a segment range. Package-private static for testing. */
  static Projection scanWindow(
      Translation2d robotPos, List<PathPlannerTrajectoryState> states, int startIdx, int endIdx) {
    int bestIdx = startIdx;
    double bestU = 0.0;
    double bestDistSq = Double.POSITIVE_INFINITY;

    for (int i = startIdx; i <= endIdx; i++) {
      var a = states.get(i).pose.getTranslation();
      var b = states.get(i + 1).pose.getTranslation();
      double abx = b.getX() - a.getX();
      double aby = b.getY() - a.getY();
      double abLenSq = abx * abx + aby * aby;
      double u;
      if (abLenSq < 1e-12) {
        u = 0.0;
      } else {
        double apx = robotPos.getX() - a.getX();
        double apy = robotPos.getY() - a.getY();
        u = (apx * abx + apy * aby) / abLenSq;
        if (u < 0.0) u = 0.0;
        else if (u > 1.0) u = 1.0;
      }
      double cx = a.getX() + u * abx;
      double cy = a.getY() + u * aby;
      double dx = robotPos.getX() - cx;
      double dy = robotPos.getY() - cy;
      double distSq = dx * dx + dy * dy;
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestIdx = i;
        bestU = u;
      }
    }

    double sA = states.get(bestIdx).distanceAlongPath;
    double sB = states.get(bestIdx + 1).distanceAlongPath;
    double arcLength = sA + bestU * (sB - sA);
    Projection out = new Projection(bestIdx, arcLength);
    out.segmentU = bestU;
    out.distance = Math.sqrt(bestDistSq);
    return out;
  }

  private ChassisSpeeds speedsToFieldFrame() {
    ChassisSpeeds robotSpeeds = speedsSupplier.get();
    return ChassisSpeeds.fromRobotRelativeSpeeds(robotSpeeds, poseSupplier.get().getRotation());
  }

  /** Internal projection result. Package-private for testing. */
  static class Projection {
    final int segmentIndex;
    final double arcLength;
    double segmentU = 0.0;
    double distance = 0.0;

    Projection(int segmentIndex, double arcLength) {
      this.segmentIndex = segmentIndex;
      this.arcLength = arcLength;
    }
  }
}
