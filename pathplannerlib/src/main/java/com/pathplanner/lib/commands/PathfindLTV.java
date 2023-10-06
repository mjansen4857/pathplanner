package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PPLTVController;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.math.Vector;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.numbers.N2;
import edu.wpi.first.math.numbers.N3;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PathfindLTV extends PathfindingCommand {
  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (robot relative)
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Vector<N3> qelems,
      Vector<N2> relems,
      double dt,
      Subsystem... requirements) {
    super(
        targetPath,
        constraints,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        new PPLTVController(qelems, relems, dt),
        0,
        requirements);
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (robot relative)
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double dt,
      Subsystem... requirements) {
    super(
        targetPath,
        constraints,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        new PPLTVController(dt),
        0,
        requirements);
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given position.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      Translation2d targetPosition,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Vector<N3> qelems,
      Vector<N2> relems,
      double dt,
      Subsystem... requirements) {
    super(
        new Pose2d(targetPosition, new Rotation2d()),
        constraints,
        goalEndVel,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        new PPLTVController(qelems, relems, dt),
        0,
        requirements);
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given position.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      Translation2d targetPosition,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double dt,
      Subsystem... requirements) {
    super(
        new Pose2d(targetPosition, new Rotation2d()),
        constraints,
        goalEndVel,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        new PPLTVController(dt),
        0,
        requirements);
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given position and
   * stop.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      Translation2d targetPosition,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Vector<N3> qelems,
      Vector<N2> relems,
      double dt,
      Subsystem... requirements) {
    this(
        targetPosition,
        constraints,
        0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        qelems,
        relems,
        dt,
        requirements);
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given position and
   * stop.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      Translation2d targetPosition,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double dt,
      Subsystem... requirements) {
    this(
        targetPosition,
        constraints,
        0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        dt,
        requirements);
  }
}
