package com.pathplanner.lib.commands;

import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.HolonomicPathFollowerConfig;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.SequentialCommandGroup;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** A command group that first pathfinds to a goal path and then follows the goal path. */
public class PathfindThenFollowPathHolonomic extends SequentialCommandGroup {
  /**
   * Constructs a new PathfindThenFollowPathHolonomic command group.
   *
   * @param goalPath the goal path to follow
   * @param pathfindingConstraints the path constraints for pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param robotRelativeOutput a consumer for the output speeds (robot relative)
   * @param config {@link com.pathplanner.lib.util.HolonomicPathFollowerConfig} for configuring the
   *     path following commands
   * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
   *     cause the robot to hold its current rotation until it reaches the given distance along the
   *     path.
   * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
   *     will maintain a global blue alliance origin.
   * @param requirements the subsystems required by this command (drive subsystem)
   */
  public PathfindThenFollowPathHolonomic(
      PathPlannerPath goalPath,
      PathConstraints pathfindingConstraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> robotRelativeOutput,
      HolonomicPathFollowerConfig config,
      double rotationDelayDistance,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    addCommands(
        new PathfindHolonomic(
            goalPath,
            pathfindingConstraints,
            poseSupplier,
            currentRobotRelativeSpeeds,
            robotRelativeOutput,
            config,
            rotationDelayDistance,
            shouldFlipPath,
            requirements),
        new FollowPathHolonomic(
            goalPath,
            poseSupplier,
            currentRobotRelativeSpeeds,
            robotRelativeOutput,
            config,
            shouldFlipPath,
            requirements));
  }

  /**
   * Constructs a new PathfindThenFollowPathHolonomic command group.
   *
   * @param goalPath the goal path to follow
   * @param pathfindingConstraints the path constraints for pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param robotRelativeOutput a consumer for the output speeds (robot relative)
   * @param config {@link com.pathplanner.lib.util.HolonomicPathFollowerConfig} for configuring the
   *     path following commands
   * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
   *     will maintain a global blue alliance origin.
   * @param requirements the subsystems required by this command (drive subsystem)
   */
  public PathfindThenFollowPathHolonomic(
      PathPlannerPath goalPath,
      PathConstraints pathfindingConstraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> robotRelativeOutput,
      HolonomicPathFollowerConfig config,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    this(
        goalPath,
        pathfindingConstraints,
        poseSupplier,
        currentRobotRelativeSpeeds,
        robotRelativeOutput,
        config,
        0.0,
        shouldFlipPath,
        requirements);
  }
}
