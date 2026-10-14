package com.pathplanner.lib.commands;

import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.PriorityQueue;
import java.util.Queue;
import java.util.Set;
import java.util.function.BiConsumer;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

import org.wpilib.command3.Command;
import org.wpilib.command3.Coroutine;
import org.wpilib.command3.Mechanism;
import org.wpilib.command3.Scheduler;
import org.wpilib.event.EventLoop;
import org.wpilib.math.geometry.Pose2d;
import org.wpilib.math.geometry.Rotation2d;
import org.wpilib.math.kinematics.ChassisVelocities;
import org.wpilib.math.system.DCMotor;
import org.wpilib.system.Timer;

import com.pathplanner.lib.config.ModuleConfig;
import com.pathplanner.lib.config.PIDConstants;
import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.events.Event;
import com.pathplanner.lib.path.EventMarker;
import com.pathplanner.lib.path.GoalEndState;
import com.pathplanner.lib.path.IdealStartingState;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.Waypoint;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import com.pathplanner.lib.util.DriveFeedforwards;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;

/** Base command for following a path */
public class FollowPathCommand implements Command {

  private final Timer timer = new Timer();

  private final PathPlannerPath originalPath;

  private final Supplier<Pose2d> poseSupplier;

  private final Supplier<ChassisVelocities> speedsSupplier;

  private final BiConsumer<ChassisVelocities, DriveFeedforwards> output;

  private final PathFollowingController controller;

  private final RobotConfig robotConfig;

  private final BooleanSupplier shouldFlipPath;

  private final Scheduler eventScheduler;

  private final EventLoop eventLoop;

  private PathPlannerPath path;

  private PathPlannerTrajectory trajectory;

  private Set<Mechanism> driveRequirements;

  private final String name;

  @Override
  public String name() {
    return name;
  }

  @Override
  public Set<Mechanism> requirements() {
    return driveRequirements;
  }

  /**
   * Construct a base path following command
   *
   * @param path           The path to follow
   * @param poseSupplier   Function that supplies the current field-relative pose
   *                       of the robot
   * @param speedsSupplier Function that supplies the current robot-relative
   *                       chassis speeds
   * @param output         Output function that accepts robot-relative
   *                       ChassisSpeeds and feedforwards for
   *                       each drive motor. If using swerve, these feedforwards
   *                       will be in FL, FR, BL, BR order. If
   *                       using a differential drive, they will be in L, R order.
   *                       <p>
   *                       NOTE: These feedforwards are assuming unoptimized
   *                       module states. When you optimize your
   *                       module states, you will need to reverse the
   *                       feedforwards for modules that have been flipped
   * @param controller     Path following controller that will be used to follow
   *                       the path
   * @param robotConfig    The robot configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the
   *                       field? This will
   *                       maintain a global blue alliance origin.
   * @param requirements   Subsystems required by this command, usually just the
   *                       drive subsystem
   */
  public FollowPathCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisVelocities> speedsSupplier,
      BiConsumer<ChassisVelocities, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      String name,
      Mechanism... requirements) {

    this.originalPath = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = output;
    this.controller = controller;
    this.robotConfig = robotConfig;
    this.shouldFlipPath = shouldFlipPath;
    this.eventScheduler = Scheduler.createIndependentScheduler();
    this.eventLoop = new EventLoop();
    this.name = name;
    this.driveRequirements = Set.of(requirements);

    // Add all event scheduler requirements to this command's requirements
    var eventReqs = getPathRequirements(this.originalPath);
    if (!Collections.disjoint(driveRequirements, eventReqs)) {
      throw new IllegalArgumentException(
          "Events that are triggered during path following cannot require the drive subsystem");
    }
    this.driveRequirements.addAll(eventReqs);

    this.path = this.originalPath;
    // Ensure the ideal trajectory is generated
    Optional<PathPlannerTrajectory> idealTrajectory = this.path.getIdealTrajectory(this.robotConfig);
    idealTrajectory.ifPresent(traj -> this.trajectory = traj);
  }

  public FollowPathCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisVelocities> speedsSupplier,
      BiConsumer<ChassisVelocities, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      Mechanism... requirements) {
    this(
        path,
        poseSupplier,
        speedsSupplier,
        output,
        controller,
        robotConfig,
        shouldFlipPath,
        "[PathPlanner] follow " + path.name,
        requirements);
  }

  private Set<Mechanism> getPathRequirements(PathPlannerPath path) {
    Set<Mechanism> allReqs = new HashSet<>();
    for (EventMarker m : path.getEventMarkers()) {
      if (m.command() != null) {
        allReqs.addAll(m.command().requirements());
      }
    }
    return allReqs;
  }

  private final Map<Command, Boolean> eventCommands = new HashMap<>();
  private final Queue<Event> upcomingEvents = new PriorityQueue<>(
      Comparator.comparingDouble(Event::getTimestampSeconds));

  private PathPlannerTrajectory setupTrajectory(Pose2d currentPose, ChassisVelocities currentSpeeds) {
    if (path.getIdealStartingState() != null) {
      // Check if we match the ideal starting state
      double linearVel = Math.hypot(currentSpeeds.vx, currentSpeeds.vy);
      boolean idealVelocity = Math.abs(linearVel - path.getIdealStartingState().velocityMPS()) <= 0.25;
      boolean idealRotation = !robotConfig.isHolonomic
          || Math.abs(
              currentPose
                  .getRotation()
                  .minus(path.getIdealStartingState().rotation())
                  .getDegrees()) <= 30.0;
      if (idealVelocity && idealRotation) {
        // We can use the ideal trajectory
        return path.getIdealTrajectory(robotConfig).orElseThrow();
      } else {
        // We need to regenerate
        return path.generateTrajectory(currentSpeeds, currentPose.getRotation(), robotConfig);
      }
    } else {
      // No ideal starting state, generate the trajectory
      return path.generateTrajectory(currentSpeeds, currentPose.getRotation(), robotConfig);
    }
  }

  @Override
  public void run(Coroutine coroutine) {
    init();

    while (tick(coroutine)) {
      coroutine.yield();
    }

    end(false);
  }

  public void init() {
    if (shouldFlipPath.getAsBoolean() && !originalPath.preventFlipping) {
      path = originalPath.flipPath();
    } else {
      path = originalPath;
    }

    Pose2d currentPose = poseSupplier.get();
    ChassisVelocities currentSpeeds = speedsSupplier.get();
    this.trajectory = setupTrajectory(currentPose, currentSpeeds);
    controller.reset(currentPose, currentSpeeds);

    PathPlannerAuto.setCurrentTrajectory(trajectory);
    PathPlannerAuto.currentPathName = originalPath.name;
    PathPlannerLogging.logActivePath(path);
    PPLibTelemetry.setCurrentPath(path);

    eventCommands.clear();
    upcomingEvents.clear();
    upcomingEvents.addAll(trajectory.getEvents());

    timer.reset();
    timer.start();
  }

  /** {@return whether the loop (command) should continue} */
  public boolean tick(Coroutine coro) {
    double currentTime = timer.get();
    var targetState = trajectory.sample(currentTime);
    if (!controller.isHolonomic() && path.isReversed()) {
      targetState = targetState.reverse();
    }

    Pose2d currentPose = poseSupplier.get();
    ChassisVelocities currentSpeeds = speedsSupplier.get();

    ChassisVelocities targetSpeeds = controller.calculateRobotRelativeSpeeds(currentPose, targetState);
    double currentVel = Math.hypot(currentSpeeds.vx, currentSpeeds.vy);
    PPLibTelemetry.setCurrentPose(currentPose);
    PathPlannerLogging.logCurrentPose(currentPose);
    PPLibTelemetry.setTargetPose(targetState.pose);
    PathPlannerLogging.logTargetPose(targetState.pose);
    PPLibTelemetry.setVelocities(
        currentVel, targetState.linearVelocity, currentSpeeds.omega, targetSpeeds.omega);
    output.accept(targetSpeeds, targetState.feedforwards);

    // Check for events that should be handled this loop
    while (!this.upcomingEvents.isEmpty() && currentTime >= this.upcomingEvents.peek().getTimestampSeconds()) {
      this.upcomingEvents.poll().handleEvent(this.eventScheduler);
    }

    // Run currently running commands
    this.eventScheduler.run();
    this.eventLoop.poll();

    double totalTime = trajectory.getTotalTimeSeconds();
    if (this.timer.hasElapsed(totalTime) || !Double.isFinite(totalTime))
      return false;
    return true;
  }

  @Override
  public void onCancel() {
    end(true);
  }

  private void end(boolean interrupted) {
    timer.stop();
    PathPlannerAuto.currentPathName = "";
    PathPlannerAuto.setCurrentTrajectory(null);
    // Only output 0 speeds when ending a path that is supposed to stop, this allows
    // interrupting
    // the command to smoothly transition into some auto-alignment routine
    if (!interrupted && path.getGoalEndState().velocityMPS() < 0.1) {
      output.accept(new ChassisVelocities(), DriveFeedforwards.zeros(robotConfig.numModules));
    }
    PathPlannerLogging.logActivePath(null);

    this.eventScheduler.cancelAll();
    for (Event e : this.upcomingEvents) {
      e.cancelEvent(this.eventScheduler);
    }
    this.eventCommands.clear();
    this.upcomingEvents.clear();
  }

  /**
   * Create a command to warmup on-the-fly generation, replanning, and the path
   * following command
   *
   * @return Path following warmup command
   */
  public static Command warmupCommand() {
    List<Waypoint> waypoints = PathPlannerPath.waypointsFromPoses(
        new Pose2d(0.0, 0.0, Rotation2d.ZERO), new Pose2d(6.0, 6.0, Rotation2d.ZERO));
    PathPlannerPath path = new PathPlannerPath(
        waypoints,
        new PathConstraints(4.0, 4.0, 4.0, 4.0),
        new IdealStartingState(0.0, Rotation2d.ZERO),
        new GoalEndState(0.0, Rotation2d.CW_90DEG));
    return new FollowPathCommand(
        path,
        () -> Pose2d.ZERO,
        ChassisVelocities::new,
        (speeds, feedforwards) -> {
        },
        new PPHolonomicDriveController(
            new PIDConstants(5.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0)),
        new RobotConfig(
            75,
            6.8,
            new ModuleConfig(
                0.048, 5.0, 1.2, DCMotor.getKrakenX60(1).withReduction(6.14), 60.0, 1),
            0.55),
        () -> true, "[PathPlanner] FollowPathCommand: internal warmup")
        .andThen(Command
            .noRequirements(_ -> System.out.println("[PathPlanner] FollowPathCommand: finished warmup"))
            .named("[PathPlanner] FollowPathCommand: notify finished warmup"))
        .named("[PathPlanner] FollowPathCommand: warmup");
  }

  public Scheduler getEventScheduler() {
    return eventScheduler;
  }

  public EventLoop getEventLoop() {
    return eventLoop;
  }
}
