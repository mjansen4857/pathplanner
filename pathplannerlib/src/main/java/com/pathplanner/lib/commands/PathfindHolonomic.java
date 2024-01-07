package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import com.pathplanner.lib.path.*;
import com.pathplanner.lib.util.HolonomicPathFollowerConfig;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Pathfind and follow the path with a PPHolonomicDriveController */
public class PathfindHolonomic extends PathfindingCommand {
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
   * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
   *     will maintain a global blue alliance origin.
   * @param requirements the subsystems required by this command
   */
  public PathfindHolonomic(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      HolonomicPathFollowerConfig config,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    this(
        targetPath,
        constraints,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        config,
        0.0,
        shouldFlipPath,
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
   * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
   *     will maintain a global blue alliance origin.
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
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    super(
        targetPath,
        constraints,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        new PPHolonomicDriveController(
            config.translationConstants,
            config.rotationConstants,
            config.period,
            config.maxModuleSpeed,
            config.driveBaseRadius),
        rotationDelayDistance,
        config.replanningConfig,
        shouldFlipPath,
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
    super(
        targetPose,
        constraints,
        goalEndVel,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        new PPHolonomicDriveController(
            config.translationConstants,
            config.rotationConstants,
            config.period,
            config.maxModuleSpeed,
            config.driveBaseRadius),
        rotationDelayDistance,
        config.replanningConfig,
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
}
