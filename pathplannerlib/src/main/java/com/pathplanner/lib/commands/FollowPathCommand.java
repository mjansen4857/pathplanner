package com.pathplanner.lib.commands;

import com.pathplanner.lib.config.ModuleConfig;
import com.pathplanner.lib.config.PIDConstants;
import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.events.EventScheduler;
import com.pathplanner.lib.path.*;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import com.pathplanner.lib.util.DriveFeedforwards;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.system.plant.DCMotor;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Commands;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.*;
import java.util.function.BiConsumer;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

/** Base command for following a path */
public class FollowPathCommand extends Command {
  private final Timer timer = new Timer();
  private final PathPlannerPath originalPath;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final BiConsumer<ChassisSpeeds, DriveFeedforwards> output;
  private final PathFollowingController controller;
  private final RobotConfig robotConfig;
  private final BooleanSupplier shouldFlipPath;
  private final EventScheduler eventScheduler;

  private PathPlannerPath path;
  private PathPlannerTrajectory trajectory;

  /**
   * Construct a base path following command
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
   *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
   *     using a differential drive, they will be in L, R order.
   *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
   *     module states, you will need to reverse the feedforwards for modules that have been flipped
   * @param controller Path following controller that will be used to follow the path
   * @param robotConfig The robot configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
   *     maintain a global blue alliance origin.
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
  public FollowPathCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      BiConsumer<ChassisSpeeds, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    this.originalPath = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = output;
    this.controller = controller;
    this.robotConfig = robotConfig;
    this.shouldFlipPath = shouldFlipPath;
    this.eventScheduler = new EventScheduler();

    Set<Subsystem> driveRequirements = Set.of(requirements);
    addRequirements(requirements);

    // Add all event scheduler requirements to this command's requirements
    var eventReqs = EventScheduler.getSchedulerRequirements(this.originalPath);
    if (!Collections.disjoint(driveRequirements, eventReqs)) {
      throw new IllegalArgumentException(
          "Events that are triggered during path following cannot require the drive subsystem");
    }
    addRequirements(eventReqs);

    this.path = this.originalPath;
    // Ensure the ideal trajectory is generated
    Optional<PathPlannerTrajectory> idealTrajectory =
        this.path.getIdealTrajectory(this.robotConfig);
    idealTrajectory.ifPresent(traj -> this.trajectory = traj);
  }

  @Override
  public void initialize() {
    PathPlannerAuto.currentPathName = originalPath.name;

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
      // Check if we match the ideal starting state
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
        // We can use the ideal trajectory
        trajectory = path.getIdealTrajectory(robotConfig).orElseThrow();
      } else {
        // We need to regenerate
        trajectory = path.generateTrajectory(currentSpeeds, currentPose.getRotation(), robotConfig);
      }
    } else {
      // No ideal starting state, generate the trajectory
      trajectory = path.generateTrajectory(currentSpeeds, currentPose.getRotation(), robotConfig);
    }

    PathPlannerLogging.logActivePath(path);
    PPLibTelemetry.setCurrentPath(path);

    eventScheduler.initialize(trajectory);

    timer.reset();
    timer.start();
  }

  @Override
  public void execute() {
    double currentTime = timer.get();
    var targetState = trajectory.sample(currentTime);
    if (!controller.isHolonomic() && path.isReversed()) {
      targetState = targetState.reverse();
    }

    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    ChassisSpeeds targetSpeeds = controller.calculateRobotRelativeSpeeds(currentPose, targetState);

    double currentVel =
        Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);

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

    eventScheduler.execute(currentTime);
  }

  @Override
  public boolean isFinished() {
    return timer.hasElapsed(trajectory.getTotalTimeSeconds());
  }

  @Override
  public void end(boolean interrupted) {
    timer.stop();
    PathPlannerAuto.currentPathName = "";

    // Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
    // the command to smoothly transition into some auto-alignment routine
    if (!interrupted && path.getGoalEndState().velocityMPS() < 0.1) {
      output.accept(new ChassisSpeeds(), DriveFeedforwards.zeros(robotConfig.numModules));
    }

    PathPlannerLogging.logActivePath(null);

    eventScheduler.end();
  }

  /**
   * Create a command to warmup on-the-fly generation, replanning, and the path following command
   *
   * @return Path following warmup command
   */
  public static Command warmupCommand() {
    List<Waypoint> waypoints =
        PathPlannerPath.waypointsFromPoses(
            new Pose2d(0.0, 0.0, Rotation2d.kZero), new Pose2d(6.0, 6.0, Rotation2d.kZero));
    PathPlannerPath path =
        new PathPlannerPath(
            waypoints,
            new PathConstraints(4.0, 4.0, 4.0, 4.0),
            new IdealStartingState(0.0, Rotation2d.kZero),
            new GoalEndState(0.0, Rotation2d.kCW_90deg));

    return new FollowPathCommand(
            path,
            () -> Pose2d.kZero,
            ChassisSpeeds::new,
            (speeds, feedforwards) -> {},
            new PPHolonomicDriveController(
                new PIDConstants(5.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0)),
            new RobotConfig(
                75,
                6.8,
                new ModuleConfig(
                    0.048, 5.0, 1.2, DCMotor.getKrakenX60(1).withReduction(6.14), 60.0, 1),
                0.55),
            () -> true)
        .andThen(Commands.print("[PathPlanner] FollowPathCommand finished warmup"))
        .ignoringDisable(true);
  }
}
