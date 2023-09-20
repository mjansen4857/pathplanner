package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.HolonomicDriveController;
import com.pathplanner.lib.path.*;
import com.pathplanner.lib.pathfinding.ADStar;
import com.pathplanner.lib.util.HolonomicPathFollowerConfig;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.Collections;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PathfindHolonomic extends Command {
  private final PathPlannerPath targetPath;
  private Pose2d targetPose;
  private final GoalEndState goalEndState;
  private final PathConstraints constraints;
  private final HolonomicDriveController controller;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final double rotationDelayDistance;
  private final Timer timer = new Timer();

  private PathPlannerTrajectory currentTrajectory;
  private Pose2d startingPose;

  /**
   * Constructs a new PathfindHolonomic command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (robot relative)
   * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
   *     following
   * @param requirements the subsystems required by this command
   */
  public PathfindHolonomic(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      HolonomicPathFollowerConfig config,
      Subsystem... requirements) {
    this(
        targetPath,
        constraints,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        config,
        0.0,
        requirements);
  }

  /**
   * Constructs a new PathfindHolonomic command that will generate a path towards the given pose.
   *
   * @param targetPose the pose to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
   *     following
   * @param requirements the subsystems required by this command
   */
  public PathfindHolonomic(
      Pose2d targetPose,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      HolonomicPathFollowerConfig config,
      Subsystem... requirements) {
    this(
        targetPose,
        constraints,
        goalEndVel,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        config,
        0.0,
        requirements);
  }

  /**
   * Constructs a new PathfindHolonomic command that will generate a path towards the given pose and
   * stop.
   *
   * @param targetPose the pose to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
   *     following
   * @param requirements the subsystems required by this command
   */
  public PathfindHolonomic(
      Pose2d targetPose,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      HolonomicPathFollowerConfig config,
      Subsystem... requirements) {
    this(
        targetPose,
        constraints,
        0.0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        config,
        requirements);
  }

  /**
   * Constructs a new PathfindHolonomic command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (robot relative)
   * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
   *     following
   * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
   *     cause the robot to hold its current rotation until it reaches the given distance along the
   *     path.
   * @param requirements the subsystems required by this command
   */
  public PathfindHolonomic(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      HolonomicPathFollowerConfig config,
      double rotationDelayDistance,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    Rotation2d targetRotation = new Rotation2d();
    for (PathPoint p : targetPath.getAllPathPoints()) {
      if (p.holonomicRotation != null) {
        targetRotation = p.holonomicRotation;
        break;
      }
    }

    this.targetPath = targetPath;
    this.targetPose = new Pose2d(this.targetPath.getPoint(0).position, targetRotation);
    this.goalEndState =
        new GoalEndState(
            this.targetPath.getGlobalConstraints().getMaxVelocityMps(), targetRotation);
    this.constraints = constraints;
    this.controller =
        new HolonomicDriveController(
            config.translationConstants,
            config.rotationConstants,
            config.period,
            config.maxModuleSpeed,
            config.driveBaseRadius);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
    this.rotationDelayDistance = rotationDelayDistance;
  }

  /**
   * Constructs a new PathfindHolonomic command that will generate a path towards the given pose.
   *
   * @param targetPose the pose to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
   *     following
   * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
   *     cause the robot to hold its current rotation until it reaches the given distance along the
   *     path.
   * @param requirements the subsystems required by this command
   */
  public PathfindHolonomic(
      Pose2d targetPose,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      HolonomicPathFollowerConfig config,
      double rotationDelayDistance,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = null;
    this.targetPose = targetPose;
    this.goalEndState = new GoalEndState(goalEndVel, targetPose.getRotation());
    this.constraints = constraints;
    this.controller =
        new HolonomicDriveController(
            config.translationConstants,
            config.rotationConstants,
            config.period,
            config.maxModuleSpeed,
            config.driveBaseRadius);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
    this.rotationDelayDistance = rotationDelayDistance;
  }

  /**
   * Constructs a new PathfindHolonomic command that will generate a path towards the given pose and
   * stop.
   *
   * @param targetPose the pose to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
   *     following
   * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
   *     cause the robot to hold its current rotation until it reaches the given distance along the
   *     path.
   * @param requirements the subsystems required by this command
   */
  public PathfindHolonomic(
      Pose2d targetPose,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      HolonomicPathFollowerConfig config,
      double rotationDelayDistance,
      Subsystem... requirements) {
    this(
        targetPose,
        constraints,
        0.0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        config,
        rotationDelayDistance,
        requirements);
  }

  @Override
  public void initialize() {
    currentTrajectory = null;

    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    controller.reset(currentPose, speedsSupplier.get());

    if (targetPath != null) {
      targetPose = new Pose2d(this.targetPath.getPoint(0).position, goalEndState.getRotation());
    }

    if (ADStar.getGridPos(currentPose.getTranslation())
        .equals(ADStar.getGridPos(targetPose.getTranslation()))) {
      this.cancel();
    } else {
      ADStar.setStartPos(currentPose.getTranslation());
      ADStar.setGoalPos(targetPose.getTranslation());
    }

    startingPose = currentPose;
  }

  @Override
  public void execute() {
    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    PathPlannerLogging.logCurrentPose(currentPose);
    PPLibTelemetry.setCurrentPose(currentPose);

    if (ADStar.isNewPathAvailable()) {
      List<Translation2d> bezierPoints = ADStar.getCurrentPath();

      if (bezierPoints.size() >= 4) {
        PathPlannerPath path =
            new PathPlannerPath(
                bezierPoints,
                Collections.emptyList(),
                Collections.emptyList(),
                Collections.emptyList(),
                constraints,
                goalEndState,
                false);

        if (currentPose.getTranslation().getDistance(path.getPoint(0).position) <= 0.25) {
          currentTrajectory = new PathPlannerTrajectory(path, currentSpeeds);

          PathPlannerLogging.logActivePath(path);
          PPLibTelemetry.setCurrentPath(path);
        } else {
          PathPlannerPath replanned = path.replan(currentPose, currentSpeeds);
          currentTrajectory = new PathPlannerTrajectory(replanned, currentSpeeds);

          PathPlannerLogging.logActivePath(replanned);
          PPLibTelemetry.setCurrentPath(replanned);
        }

        timer.reset();
        timer.start();
      }
    }

    if (currentTrajectory != null) {
      PathPlannerTrajectory.State targetState = currentTrajectory.sample(timer.get());

      // Set the target rotation to the starting rotation if we have not yet traveled the rotation
      // delay distance
      if (currentPose.getTranslation().getDistance(startingPose.getTranslation())
          < rotationDelayDistance) {
        targetState.targetHolonomicRotation = startingPose.getRotation();
      }

      ChassisSpeeds targetSpeeds = controller.calculate(currentPose, targetState);

      double currentVel =
          Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);

      PPLibTelemetry.setCurrentPose(currentPose);
      PPLibTelemetry.setTargetPose(targetState.getTargetHolonomicPose());
      PathPlannerLogging.logCurrentPose(currentPose);
      PathPlannerLogging.logTargetPose(targetState.getTargetHolonomicPose());
      PPLibTelemetry.setVelocities(
          currentVel,
          targetState.velocityMps,
          currentSpeeds.omegaRadiansPerSecond,
          targetSpeeds.omegaRadiansPerSecond);
      PPLibTelemetry.setPathInaccuracy(controller.getPositionalError());

      output.accept(targetSpeeds);
    }
  }

  @Override
  public boolean isFinished() {
    if (targetPath != null) {
      Pose2d currentPose = poseSupplier.get();
      ChassisSpeeds currentSpeeds = speedsSupplier.get();

      double currentVel =
          Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);
      double stoppingDistance =
          Math.pow(currentVel, 2) / (2 * constraints.getMaxAccelerationMpsSq());

      return currentPose.getTranslation().getDistance(targetPath.getPoint(0).position)
          <= stoppingDistance;
    }

    if (currentTrajectory != null) {
      return timer.hasElapsed(currentTrajectory.getTotalTimeSeconds());
    }

    return false;
  }

  @Override
  public void end(boolean interrupted) {
    // Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
    // the command to smoothly transition into some auto-alignment routine
    if (!interrupted && goalEndState.getVelocity() < 0.1) {
      output.accept(new ChassisSpeeds());
    }

    timer.stop();
  }
}
