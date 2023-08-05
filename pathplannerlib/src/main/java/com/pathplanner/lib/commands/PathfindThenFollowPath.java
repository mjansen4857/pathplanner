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

public class PathfindThenFollowPath extends SequentialCommandGroup {
  public PathfindThenFollowPath(
      PathPlannerPath goalPath,
      PathConstraints pathfindingConstraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> fieldRelativeOutput,
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
            fieldRelativeOutput,
            requirements),
        new HolonomicFollowPathCommand(
            goalPath, poseSupplier, currentRobotRelativeSpeeds, fieldRelativeOutput, requirements));
  }
}
