package com.pathplanner.lib.commands;

import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.HolonomicPathFollowerConfig;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.SequentialCommandGroup;
import edu.wpi.first.wpilibj2.command.Subsystem;
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
   * @param requirements the subsystems required by this command (drive subsystem)
   */
  public PathfindThenFollowPathHolonomic(
      PathPlannerPath goalPath,
      PathConstraints pathfindingConstraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> robotRelativeOutput,
      HolonomicPathFollowerConfig config,
      Subsystem... requirements) {
    addCommands(
        new PathfindHolonomic(
            goalPath,
            pathfindingConstraints,
            poseSupplier,
            currentRobotRelativeSpeeds,
            robotRelativeOutput,
            config,
            requirements),
        new FollowPathHolonomic(
            goalPath,
            poseSupplier,
            currentRobotRelativeSpeeds,
            robotRelativeOutput,
            config,
            requirements));
  }
}
