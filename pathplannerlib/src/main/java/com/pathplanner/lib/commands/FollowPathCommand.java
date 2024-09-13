package com.pathplanner.lib.commands;

import com.pathplanner.lib.config.ModuleConfig;
import com.pathplanner.lib.config.MotorTorqueCurve;
import com.pathplanner.lib.config.PIDConstants;
import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.path.*;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.Pair;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Commands;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.*;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Base command for following a path */
public class FollowPathCommand extends Command {
  private final Timer timer = new Timer();
  private final PathPlannerPath originalPath;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final PathFollowingController controller;
  private final RobotConfig robotConfig;
  private final BooleanSupplier shouldFlipPath;

  // For event markers
  private final Map<Command, Boolean> currentEventCommands = new HashMap<>();
  private final List<Pair<Double, Command>> untriggeredEvents = new ArrayList<>();

  private PathPlannerPath path;
  private PathPlannerTrajectory trajectory;

  /**
   * Construct a base path following command
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param outputRobotRelative Function that will apply the robot-relative output speeds of this
   *     command
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
      Consumer<ChassisSpeeds> outputRobotRelative,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    this.originalPath = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = outputRobotRelative;
    this.controller = controller;
    this.robotConfig = robotConfig;
    this.shouldFlipPath = shouldFlipPath;

    Set<Subsystem> driveRequirements = Set.of(requirements);
    addRequirements(requirements);

    for (EventMarker marker : this.originalPath.getEventMarkers()) {
      var reqs = marker.getCommand().getRequirements();

      if (!Collections.disjoint(driveRequirements, reqs)) {
        throw new IllegalArgumentException(
            "Events that are triggered during path following cannot require the drive subsystem");
      }

      addRequirements(reqs.toArray(new Subsystem[0]));
    }

    this.path = this.originalPath;
    // Ensure the ideal trajectory is generated
    Optional<PathPlannerTrajectory> idealTrajectory =
        this.path.getIdealTrajectory(this.robotConfig);
    idealTrajectory.ifPresent(traj -> this.trajectory = traj);
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
      // Check if we match the ideal starting state
      boolean idealVelocity =
          Math.abs(linearVel - path.getIdealStartingState().getVelocity()) <= 0.25;
      boolean idealRotation =
          !robotConfig.isHolonomic
              || Math.abs(
                      currentPose
                          .getRotation()
                          .minus(path.getIdealStartingState().getRotation())
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

    // Initialize marker stuff
    currentEventCommands.clear();
    untriggeredEvents.clear();
    untriggeredEvents.addAll(trajectory.getEventCommands());

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
    PPLibTelemetry.setPathInaccuracy(controller.getPositionalError());

    output.accept(targetSpeeds);

    if (!untriggeredEvents.isEmpty() && timer.hasElapsed(untriggeredEvents.get(0).getFirst())) {
      // Time to trigger this event command
      Pair<Double, Command> event = untriggeredEvents.remove(0);

      for (var runningCommand : currentEventCommands.entrySet()) {
        if (!runningCommand.getValue()) {
          continue;
        }

        if (!Collections.disjoint(
            runningCommand.getKey().getRequirements(), event.getSecond().getRequirements())) {
          runningCommand.getKey().end(true);
          runningCommand.setValue(false);
        }
      }

      event.getSecond().initialize();
      currentEventCommands.put(event.getSecond(), true);
    }

    // Run event marker commands
    for (Map.Entry<Command, Boolean> runningCommand : currentEventCommands.entrySet()) {
      if (!runningCommand.getValue()) {
        continue;
      }

      runningCommand.getKey().execute();

      if (runningCommand.getKey().isFinished()) {
        runningCommand.getKey().end(false);
        runningCommand.setValue(false);
      }
    }
  }

  @Override
  public boolean isFinished() {
    return timer.hasElapsed(trajectory.getTotalTimeSeconds());
  }

  @Override
  public void end(boolean interrupted) {
    timer.stop();

    // Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
    // the command to smoothly transition into some auto-alignment routine
    if (!interrupted && path.getGoalEndState().getVelocity() < 0.1) {
      output.accept(new ChassisSpeeds());
    }

    PathPlannerLogging.logActivePath(null);

    // End markers
    for (Map.Entry<Command, Boolean> runningCommand : currentEventCommands.entrySet()) {
      if (runningCommand.getValue()) {
        runningCommand.getKey().end(true);
      }
    }
  }

  /**
   * Create a command to warmup on-the-fly generation, replanning, and the path following command
   *
   * @return Path following warmup command
   */
  public static Command warmupCommand() {
    List<Translation2d> bezierPoints =
        PathPlannerPath.bezierFromPoses(
            new Pose2d(0.0, 0.0, new Rotation2d()), new Pose2d(6.0, 6.0, new Rotation2d()));
    PathPlannerPath path =
        new PathPlannerPath(
            bezierPoints,
            new PathConstraints(4.0, 4.0, 4.0, 4.0),
            new IdealStartingState(0.0, Rotation2d.kZero),
            new GoalEndState(0.0, Rotation2d.kCCW_90deg));

    return new FollowPathCommand(
            path,
            Pose2d::new,
            ChassisSpeeds::new,
            (speeds) -> {},
            new PPHolonomicDriveController(
                new PIDConstants(5.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0)),
            new RobotConfig(
                75,
                6.8,
                new ModuleConfig(
                    0.048,
                    6.14,
                    5600,
                    1.2,
                    new MotorTorqueCurve(
                        MotorTorqueCurve.MotorType.krakenX60, MotorTorqueCurve.CurrentLimit.k60A)),
                0.55),
            () -> true)
        .andThen(Commands.print("[PathPlanner] FollowPathCommand finished warmup"))
        .ignoringDisable(true);
  }
}
