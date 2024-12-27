package com.pathplanner.lib.commands;

import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.path.GoalEndState;
import com.pathplanner.lib.path.IdealStartingState;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.DriveFeedforwards;
import com.pathplanner.lib.util.FlippingUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.Commands;
import edu.wpi.first.wpilibj2.command.SequentialCommandGroup;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.Set;
import java.util.function.BiConsumer;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

/** Command group that will pathfind to the start of a path, then follow that path */
public class PathfindThenFollowPath extends SequentialCommandGroup {
  /**
   * Constructs a new PathfindThenFollowPath command group.
   *
   * @param goalPath the goal path to follow
   * @param pathfindingConstraints the path constraints for pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
   *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
   *     using a differential drive, they will be in L, R order.
   *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
   *     module states, you will need to reverse the feedforwards for modules that have been flipped
   * @param controller Path following controller that will be used to follow the path
   * @param robotConfig The robot configuration
   * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
   *     will maintain a global blue alliance origin.
   * @param requirements the subsystems required by this command (drive subsystem)
   */
  public PathfindThenFollowPath(
      PathPlannerPath goalPath,
      PathConstraints pathfindingConstraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      BiConsumer<ChassisSpeeds, DriveFeedforwards> output,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    addCommands(
        new PathfindingCommand(
            goalPath,
            pathfindingConstraints,
            poseSupplier,
            currentRobotRelativeSpeeds,
            output,
            controller,
            robotConfig,
            shouldFlipPath,
            requirements),
        // Use a deferred command to generate an on-the-fly path to join
        // the end of the pathfinding command to the start of the path
        Commands.defer(
            () -> {
              if (goalPath.numPoints() < 2) {
                return Commands.none();
              }

              Pose2d startPose = poseSupplier.get();
              ChassisSpeeds startSpeeds = currentRobotRelativeSpeeds.get();
              ChassisSpeeds startFieldSpeeds =
                  ChassisSpeeds.fromRobotRelativeSpeeds(startSpeeds, startPose.getRotation());
              Rotation2d startHeading =
                  new Rotation2d(
                      startFieldSpeeds.vxMetersPerSecond, startFieldSpeeds.vyMetersPerSecond);

              Pose2d endWaypoint =
                  new Pose2d(goalPath.getPoint(0).position, goalPath.getInitialHeading());
              boolean shouldFlip = shouldFlipPath.getAsBoolean() && !goalPath.preventFlipping;
              if (shouldFlip) {
                endWaypoint = FlippingUtil.flipFieldPose(endWaypoint);
              }

              GoalEndState endState;
              if (goalPath.getIdealStartingState() != null) {
                Rotation2d endRot = goalPath.getIdealStartingState().rotation();
                if (shouldFlip) {
                  endRot = FlippingUtil.flipFieldRotation(endRot);
                }
                endState = new GoalEndState(goalPath.getIdealStartingState().velocityMPS(), endRot);
              } else {
                endState =
                    new GoalEndState(
                        pathfindingConstraints.maxVelocityMPS(), startPose.getRotation());
              }

              PathPlannerPath joinPath =
                  new PathPlannerPath(
                      PathPlannerPath.waypointsFromPoses(
                          new Pose2d(startPose.getTranslation(), startHeading), endWaypoint),
                      pathfindingConstraints,
                      new IdealStartingState(
                          Math.hypot(startSpeeds.vxMetersPerSecond, startSpeeds.vyMetersPerSecond),
                          startPose.getRotation()),
                      endState);
              joinPath.preventFlipping = true;

              return new FollowPathCommand(
                  joinPath,
                  poseSupplier,
                  currentRobotRelativeSpeeds,
                  output,
                  controller,
                  robotConfig,
                  shouldFlipPath,
                  requirements);
            },
            Set.of(requirements)),
        new FollowPathCommand(
            goalPath,
            poseSupplier,
            currentRobotRelativeSpeeds,
            output,
            controller,
            robotConfig,
            shouldFlipPath,
            requirements));
  }
}
