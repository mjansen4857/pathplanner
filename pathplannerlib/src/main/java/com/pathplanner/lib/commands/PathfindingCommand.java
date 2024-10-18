package com.pathplanner.lib.commands;

import static edu.wpi.first.units.Units.MetersPerSecond;

import com.pathplanner.lib.config.ModuleConfig;
import com.pathplanner.lib.config.PIDConstants;
import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.path.*;
import com.pathplanner.lib.pathfinding.Pathfinding;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import com.pathplanner.lib.util.*;
import edu.wpi.first.hal.FRCNetComm.tResourceType;
import edu.wpi.first.hal.HAL;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.system.plant.DCMotor;
import edu.wpi.first.units.measure.LinearVelocity;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Commands;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.BiConsumer;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

/** Base pathfinding command */
public class PathfindingCommand extends Command {
  private static int instances = 0;

  private final Timer timer = new Timer();
  private final PathPlannerPath targetPath;
  private Pose2d targetPose;
  private Pose2d originalTargetPose;
  private GoalEndState goalEndState;
  private final PathConstraints constraints;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final BiConsumer<ChassisSpeeds, DriveFeedforwards> output;
  private final PathFollowingController controller;
  private final RobotConfig robotConfig;
  private final BooleanSupplier shouldFlipPath;

  private PathPlannerPath currentPath;
  private PathPlannerTrajectory currentTrajectory;

  private double timeOffset = 0;

  private boolean finish = false;

  /**
   * Constructs a new base pathfinding command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param speedsSupplier a supplier for the robot's current robot relative speeds
   * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
   *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
   *     using a differential drive, they will be in L, R order.
   *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
   *     module states, you will need to reverse the feedforwards for modules that have been flipped
   * @param controller Path following controller that will be used to follow the path
   * @param robotConfig The robot configuration
   * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
   *     will maintain a global blue alliance origin.
   * @param requirements the subsystems required by this command
   */
  public PathfindingCommand(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      BiConsumer<ChassisSpeeds, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    addRequirements(requirements);

    Pathfinding.ensureInitialized();

    Rotation2d targetRotation = Rotation2d.kZero;
    double goalEndVel = targetPath.getGlobalConstraints().maxVelocityMPS();
    if (targetPath.isChoreoPath()) {
      // Can get() here without issue since all choreo trajectories have ideal trajectories
      PathPlannerTrajectory choreoTraj = targetPath.getIdealTrajectory(robotConfig).orElseThrow();
      targetRotation = choreoTraj.getInitialState().pose.getRotation();
      goalEndVel = choreoTraj.getInitialState().linearVelocity;
    } else {
      for (PathPoint p : targetPath.getAllPathPoints()) {
        if (p.rotationTarget != null) {
          targetRotation = p.rotationTarget.rotation();
          break;
        }
      }
    }

    this.targetPath = targetPath;
    this.targetPose = new Pose2d(this.targetPath.getPoint(0).position, targetRotation);
    this.originalTargetPose =
        new Pose2d(this.targetPose.getTranslation(), this.targetPose.getRotation());
    this.goalEndState = new GoalEndState(goalEndVel, targetRotation);
    this.constraints = constraints;
    this.controller = controller;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = output;
    this.robotConfig = robotConfig;
    this.shouldFlipPath = shouldFlipPath;

    instances++;
    HAL.report(tResourceType.kResourceType_PathFindingCommand, instances);
  }

  /**
   * Constructs a new base pathfinding command that will generate a path towards the given pose.
   *
   * @param targetPose the pose to pathfind to, the rotation component is only relevant for
   *     holonomic drive trains
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the target pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param speedsSupplier a supplier for the robot's current robot relative speeds
   * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
   *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
   *     using a differential drive, they will be in L, R order.
   *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
   *     module states, you will need to reverse the feedforwards for modules that have been flipped
   * @param controller Path following controller that will be used to follow the path
   * @param robotConfig The robot configuration
   * @param requirements the subsystems required by this command
   */
  public PathfindingCommand(
      Pose2d targetPose,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      BiConsumer<ChassisSpeeds, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      Subsystem... requirements) {
    addRequirements(requirements);

    Pathfinding.ensureInitialized();

    this.targetPath = null;
    this.targetPose = targetPose;
    this.originalTargetPose =
        new Pose2d(this.targetPose.getTranslation(), this.targetPose.getRotation());
    this.goalEndState = new GoalEndState(goalEndVel, targetPose.getRotation());
    this.constraints = constraints;
    this.controller = controller;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = output;
    this.robotConfig = robotConfig;
    this.shouldFlipPath = () -> false;

    instances++;
    HAL.report(tResourceType.kResourceType_PathFindingCommand, instances);
  }

  /**
   * Constructs a new base pathfinding command that will generate a path towards the given pose.
   *
   * @param targetPose the pose to pathfind to, the rotation component is only relevant for
   *     holonomic drive trains
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the target pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param speedsSupplier a supplier for the robot's current robot relative speeds
   * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
   *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
   *     using a differential drive, they will be in L, R order.
   *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
   *     module states, you will need to reverse the feedforwards for modules that have been flipped
   * @param controller Path following controller that will be used to follow the path
   * @param robotConfig The robot configuration
   * @param requirements the subsystems required by this command
   */
  public PathfindingCommand(
      Pose2d targetPose,
      PathConstraints constraints,
      LinearVelocity goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      BiConsumer<ChassisSpeeds, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      Subsystem... requirements) {
    this(
        targetPose,
        constraints,
        goalEndVel.in(MetersPerSecond),
        poseSupplier,
        speedsSupplier,
        output,
        controller,
        robotConfig,
        requirements);
  }

  /**
   * Constructs a new base pathfinding command that will generate a path towards the given pose.
   *
   * @param targetPose the pose to pathfind to, the rotation component is only relevant for
   *     holonomic drive trains
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param speedsSupplier a supplier for the robot's current robot relative speeds
   * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
   *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
   *     using a differential drive, they will be in L, R order.
   *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
   *     module states, you will need to reverse the feedforwards for modules that have been flipped
   * @param controller Path following controller that will be used to follow the path
   * @param robotConfig The robot configuration
   * @param requirements the subsystems required by this command
   */
  public PathfindingCommand(
      Pose2d targetPose,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      BiConsumer<ChassisSpeeds, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      Subsystem... requirements) {
    this(
        targetPose,
        constraints,
        0.0,
        poseSupplier,
        speedsSupplier,
        output,
        controller,
        robotConfig,
        requirements);
  }

  @Override
  public void initialize() {
    currentTrajectory = null;
    timeOffset = 0;
    finish = false;

    Pose2d currentPose = poseSupplier.get();

    controller.reset(currentPose, speedsSupplier.get());

    if (targetPath != null) {
      originalTargetPose =
          new Pose2d(this.targetPath.getPoint(0).position, originalTargetPose.getRotation());
      if (shouldFlipPath.getAsBoolean()) {
        targetPose = FlippingUtil.flipFieldPose(this.originalTargetPose);
        goalEndState = new GoalEndState(goalEndState.velocityMPS(), targetPose.getRotation());
      }
    }

    if (currentPose.getTranslation().getDistance(targetPose.getTranslation()) < 0.5) {
      output.accept(new ChassisSpeeds(), DriveFeedforwards.zeros(robotConfig.numModules));
      finish = true;
    } else {
      Pathfinding.setStartPosition(currentPose.getTranslation());
      Pathfinding.setGoalPosition(targetPose.getTranslation());
    }
  }

  @Override
  public void execute() {
    if (finish) {
      return;
    }

    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    PathPlannerLogging.logCurrentPose(currentPose);
    PPLibTelemetry.setCurrentPose(currentPose);

    // Skip new paths if we are close to the end
    boolean skipUpdates =
        currentTrajectory != null
            && currentPose
                    .getTranslation()
                    .getDistance(currentTrajectory.getEndState().pose.getTranslation())
                < 2.0;

    if (!skipUpdates && Pathfinding.isNewPathAvailable()) {
      currentPath = Pathfinding.getCurrentPath(constraints, goalEndState);

      if (currentPath != null) {
        currentTrajectory =
            new PathPlannerTrajectory(
                currentPath, currentSpeeds, currentPose.getRotation(), robotConfig);

        // Find the two closest states in front of and behind robot
        int closestState1Idx = 0;
        int closestState2Idx = 1;
        while (closestState2Idx < currentTrajectory.getStates().size() - 1) {
          double closest2Dist =
              currentTrajectory
                  .getState(closestState2Idx)
                  .pose
                  .getTranslation()
                  .getDistance(currentPose.getTranslation());
          double nextDist =
              currentTrajectory
                  .getState(closestState2Idx + 1)
                  .pose
                  .getTranslation()
                  .getDistance(currentPose.getTranslation());
          if (nextDist < closest2Dist) {
            closestState1Idx++;
            closestState2Idx++;
          } else {
            break;
          }
        }

        // Use the closest 2 states to interpolate what the time offset should be
        // This will account for the delay in pathfinding
        var closestState1 = currentTrajectory.getState(closestState1Idx);
        var closestState2 = currentTrajectory.getState(closestState2Idx);

        double d =
            closestState1.pose.getTranslation().getDistance(closestState2.pose.getTranslation());
        double t =
            (currentPose.getTranslation().getDistance(closestState1.pose.getTranslation())) / d;
        t = MathUtil.clamp(t, 0.0, 1.0);

        timeOffset = MathUtil.interpolate(closestState1.timeSeconds, closestState2.timeSeconds, t);

        // If the robot is stationary and at the start of the path, set the time offset to the next
        // loop
        // This can prevent an issue where the robot will remain stationary if new paths come in
        // every loop
        if (timeOffset <= 0.02
            && Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond) < 0.1) {
          timeOffset = 0.02;
        }

        PathPlannerLogging.logActivePath(currentPath);
        PPLibTelemetry.setCurrentPath(currentPath);
      }

      timer.reset();
      timer.start();
    }

    if (currentTrajectory != null) {
      var targetState = currentTrajectory.sample(timer.get() + timeOffset);

      ChassisSpeeds targetSpeeds =
          controller.calculateRobotRelativeSpeeds(currentPose, targetState);

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
    }
  }

  @Override
  public boolean isFinished() {
    if (finish) {
      return true;
    }

    if (targetPath != null && !targetPath.isChoreoPath()) {
      Pose2d currentPose = poseSupplier.get();
      ChassisSpeeds currentSpeeds = speedsSupplier.get();

      double currentVel =
          Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);
      double stoppingDistance = Math.pow(currentVel, 2) / (2 * constraints.maxAccelerationMPSSq());

      return currentPose.getTranslation().getDistance(targetPose.getTranslation())
          <= stoppingDistance;
    }

    if (currentTrajectory != null) {
      return timer.hasElapsed(currentTrajectory.getTotalTimeSeconds() - timeOffset);
    }

    return false;
  }

  @Override
  public void end(boolean interrupted) {
    timer.stop();

    // Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
    // the command to smoothly transition into some auto-alignment routine
    if (!interrupted && goalEndState.velocityMPS() < 0.1) {
      output.accept(new ChassisSpeeds(), DriveFeedforwards.zeros(robotConfig.numModules));
    }

    PathPlannerLogging.logActivePath(null);
  }

  /**
   * Create a command to warmup the pathfinder and pathfinding command
   *
   * @return Pathfinding warmup command
   */
  public static Command warmupCommand() {
    return new PathfindingCommand(
            new Pose2d(15.0, 4.0, Rotation2d.k180deg),
            new PathConstraints(4, 3, 4, 4),
            () -> new Pose2d(1.5, 4, Rotation2d.kZero),
            ChassisSpeeds::new,
            (speeds, feedforwards) -> {},
            new PPHolonomicDriveController(
                new PIDConstants(5.0, 0.0, 0.0), new PIDConstants(5.0, 0.0, 0.0)),
            new RobotConfig(
                75,
                6.8,
                new ModuleConfig(
                    0.048, 5.0, 1.2, DCMotor.getKrakenX60(1).withReduction(6.14), 60.0, 1),
                0.55))
        .andThen(Commands.print("[PathPlanner] PathfindingCommand finished warmup"))
        .ignoringDisable(true);
  }
}
