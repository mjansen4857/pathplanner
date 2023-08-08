package com.pathplanner.lib.commands;

import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPoint;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.SequentialCommandGroup;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

/**
 * A command group that first pathfinds to a goal path and then follows the goal path using a Pure
 * Pursuit controller.
 */
public class PathfindThenFollowPath extends SequentialCommandGroup {
  /**
   * Constructs a new PathfindThenFollowPath command group.
   *
   * @param goalPath the goal path to follow
   * @param pathfindingConstraints the path constraints for pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param holonomic whether the robot is holonomic or not
   * @param requirements the subsystems required by this command (drive subsystem)
   */
  public PathfindThenFollowPath(
      PathPlannerPath goalPath,
      PathConstraints pathfindingConstraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      boolean holonomic,
      Subsystem... requirements) {
    Rotation2d targetRotation = null;
    for (PathPoint p : goalPath.getAllPathPoints()) {
      if (p.holonomicRotation != null) {
        targetRotation = p.holonomicRotation;
        break;
      }
    }

    addCommands(
        new PathfindCommand(
            goalPath,
            targetRotation,
            pathfindingConstraints,
            poseSupplier,
            currentRobotRelativeSpeeds,
            output,
            holonomic,
            requirements),
        new FollowPathCommand(
            goalPath, poseSupplier, currentRobotRelativeSpeeds, output, holonomic, requirements));
  }
}
