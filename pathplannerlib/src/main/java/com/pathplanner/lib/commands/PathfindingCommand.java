package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.path.*;
import com.pathplanner.lib.pathfinding.Pathfinding;
import com.pathplanner.lib.util.GeometryUtil;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import com.pathplanner.lib.util.ReplanningConfig;
import edu.wpi.first.hal.FRCNetComm.tResourceType;
import edu.wpi.first.hal.HAL;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
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
  private final Consumer<ChassisSpeeds> output;
  private final PathFollowingController controller;
  private final double rotationDelayDistance;
  private final ReplanningConfig replanningConfig;
  private final BooleanSupplier shouldFlipPath;

  private PathPlannerPath currentPath;
  private PathPlannerTrajectory currentTrajectory;
  private Pose2d startingPose;

  private double timeOffset = 0;

  /**
   * Constructs a new base pathfinding command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param speedsSupplier a supplier for the robot's current robot relative speeds
   * @param outputRobotRelative a consumer for the output speeds (robot relative)
   * @param controller Path following controller that will be used to follow the path
   * @param rotationDelayDistance How far the robot should travel before attempting to rotate to the
   *     final rotation
   * @param replanningConfig Path replanning configuration
   * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
   *     will maintain a global blue alliance origin.
   * @param requirements the subsystems required by this command
   */
  public PathfindingCommand(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      PathFollowingController controller,
      double rotationDelayDistance,
      ReplanningConfig replanningConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    addRequirements(requirements);

    Pathfinding.ensureInitialized();

    Rotation2d targetRotation = new Rotation2d();
    double goalEndVel = targetPath.getGlobalConstraints().getMaxVelocityMps();
    if (targetPath.isChoreoPath()) {
      // Can call getTrajectory here without proper speeds since it will just return the choreo
      // trajectory
      PathPlannerTrajectory choreoTraj =
          targetPath.getTrajectory(new ChassisSpeeds(), new Rotation2d());
      targetRotation = choreoTraj.getInitialState().targetHolonomicRotation;
      goalEndVel = choreoTraj.getInitialState().velocityMps;
    } else {
      for (PathPoint p : targetPath.getAllPathPoints()) {
        if (p.rotationTarget != null) {
          targetRotation = p.rotationTarget.getTarget();
          break;
        }
      }
    }

    this.targetPath = targetPath;
    this.targetPose = new Pose2d(this.targetPath.getPoint(0).position, targetRotation);
    this.originalTargetPose =
        new Pose2d(this.targetPose.getTranslation(), this.targetPose.getRotation());
    this.goalEndState = new GoalEndState(goalEndVel, targetRotation, true);
    this.constraints = constraints;
    this.controller = controller;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = outputRobotRelative;
    this.rotationDelayDistance = rotationDelayDistance;
    this.replanningConfig = replanningConfig;
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
   * @param outputRobotRelative a consumer for the output speeds (robot relative)
   * @param controller Path following controller that will be used to follow the path
   * @param rotationDelayDistance How far the robot should travel before attempting to rotate to the
   *     final rotation
   * @param replanningConfig Path replanning configuration
   * @param requirements the subsystems required by this command
   */
  public PathfindingCommand(
      Pose2d targetPose,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      PathFollowingController controller,
      double rotationDelayDistance,
      ReplanningConfig replanningConfig,
      Subsystem... requirements) {
    addRequirements(requirements);

    Pathfinding.ensureInitialized();

    this.targetPath = null;
    this.targetPose = targetPose;
    this.originalTargetPose =
        new Pose2d(this.targetPose.getTranslation(), this.targetPose.getRotation());
    this.goalEndState = new GoalEndState(goalEndVel, targetPose.getRotation(), true);
    this.constraints = constraints;
    this.controller = controller;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = outputRobotRelative;
    this.rotationDelayDistance = rotationDelayDistance;
    this.replanningConfig = replanningConfig;
    this.shouldFlipPath = () -> false;

    instances++;
    HAL.report(tResourceType.kResourceType_PathFindingCommand, instances);
  }

  @Override
  public void initialize() {
    currentTrajectory = null;
    timeOffset = 0;

    Pose2d currentPose = poseSupplier.get();

    controller.reset(currentPose, speedsSupplier.get());

    if (targetPath != null) {
      originalTargetPose =
          new Pose2d(this.targetPath.getPoint(0).position, originalTargetPose.getRotation());
      if (shouldFlipPath.getAsBoolean()) {
        targetPose = GeometryUtil.flipFieldPose(this.originalTargetPose);
        goalEndState = new GoalEndState(goalEndState.getVelocity(), targetPose.getRotation(), true);
      }
    }

    if (currentPose.getTranslation().getDistance(targetPose.getTranslation()) < 0.5) {
      output.accept(new ChassisSpeeds());
      this.cancel();
    } else {
      Pathfinding.setStartPosition(currentPose.getTranslation());
      Pathfinding.setGoalPosition(targetPose.getTranslation());
    }

    startingPose = currentPose;
  }

  @Override
  public void execute() {
    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    PathPlannerLogging.logCurrentPose(currentPose);
    PPLibTelemetry.setCurrentPose(currentPose);

    // Skip new paths if we are close to the end
    boolean skipUpdates =
        currentTrajectory != null
            && currentPose
                    .getTranslation()
                    .getDistance(currentTrajectory.getEndState().positionMeters)
                < 2.0;

    if (!skipUpdates && Pathfinding.isNewPathAvailable()) {
      currentPath = Pathfinding.getCurrentPath(constraints, goalEndState);

      if (currentPath != null) {
        currentTrajectory =
            new PathPlannerTrajectory(currentPath, currentSpeeds, currentPose.getRotation());

        // Find the two closest states in front of and behind robot
        int closestState1Idx = 0;
        int closestState2Idx = 1;
        while (closestState2Idx < currentTrajectory.getStates().size() - 1) {
          double closest2Dist =
              currentTrajectory
                  .getState(closestState2Idx)
                  .positionMeters
                  .getDistance(currentPose.getTranslation());
          double nextDist =
              currentTrajectory
                  .getState(closestState2Idx + 1)
                  .positionMeters
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

        ChassisSpeeds fieldRelativeSpeeds =
            ChassisSpeeds.fromRobotRelativeSpeeds(currentSpeeds, currentPose.getRotation());
        Rotation2d currentHeading =
            new Rotation2d(
                fieldRelativeSpeeds.vxMetersPerSecond, fieldRelativeSpeeds.vyMetersPerSecond);
        Rotation2d headingError = currentHeading.minus(closestState1.heading);
        boolean onHeading =
            Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond) < 1.0
                || Math.abs(headingError.getDegrees()) < 45;

        // Replan the path if our heading is off
        if (onHeading || !replanningConfig.enableInitialReplanning) {
          double d = closestState1.positionMeters.getDistance(closestState2.positionMeters);
          double t = (currentPose.getTranslation().getDistance(closestState1.positionMeters)) / d;
          t = MathUtil.clamp(t, 0.0, 1.0);

          timeOffset =
              GeometryUtil.doubleLerp(closestState1.timeSeconds, closestState2.timeSeconds, t);

          // If the robot is stationary and at the start of the path, set the time offset to the
          // next loop
          // This can prevent an issue where the robot will remain stationary if new paths come in
          // every loop
          if (timeOffset <= 0.02
              && Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond)
                  < 0.1) {
            timeOffset = 0.02;
          }
        } else {
          currentPath = currentPath.replan(currentPose, currentSpeeds);
          currentTrajectory =
              new PathPlannerTrajectory(currentPath, currentSpeeds, currentPose.getRotation());

          timeOffset = 0;
        }

        PathPlannerLogging.logActivePath(currentPath);
        PPLibTelemetry.setCurrentPath(currentPath);
      }

      timer.reset();
      timer.start();
    }

    if (currentTrajectory != null) {
      PathPlannerTrajectory.State targetState = currentTrajectory.sample(timer.get() + timeOffset);

      if (replanningConfig.enableDynamicReplanning) {
        double previousError = Math.abs(controller.getPositionalError());
        double currentError = currentPose.getTranslation().getDistance(targetState.positionMeters);

        if (currentError >= replanningConfig.dynamicReplanningTotalErrorThreshold
            || currentError - previousError
                >= replanningConfig.dynamicReplanningErrorSpikeThreshold) {
          replanPath(currentPose, currentSpeeds);
          timer.reset();
          timeOffset = 0.0;
          targetState = currentTrajectory.sample(0);
        }
      }

      // Set the target rotation to the starting rotation if we have not yet traveled the rotation
      // delay distance
      if (currentPose.getTranslation().getDistance(startingPose.getTranslation())
          < rotationDelayDistance) {
        targetState.targetHolonomicRotation = startingPose.getRotation();
      }

      ChassisSpeeds targetSpeeds =
          controller.calculateRobotRelativeSpeeds(currentPose, targetState);

      double currentVel =
          Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);

      PPLibTelemetry.setCurrentPose(currentPose);
      PathPlannerLogging.logCurrentPose(currentPose);

      if (controller.isHolonomic()) {
        PPLibTelemetry.setTargetPose(targetState.getTargetHolonomicPose());
        PathPlannerLogging.logTargetPose(targetState.getTargetHolonomicPose());
      } else {
        PPLibTelemetry.setTargetPose(targetState.getDifferentialPose());
        PathPlannerLogging.logTargetPose(targetState.getDifferentialPose());
      }

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
    if (targetPath != null && !targetPath.isChoreoPath()) {
      Pose2d currentPose = poseSupplier.get();
      ChassisSpeeds currentSpeeds = speedsSupplier.get();

      double currentVel =
          Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);
      double stoppingDistance =
          Math.pow(currentVel, 2) / (2 * constraints.getMaxAccelerationMpsSq());

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
    if (!interrupted && goalEndState.getVelocity() < 0.1) {
      output.accept(new ChassisSpeeds());
    }

    PathPlannerLogging.logActivePath(null);
  }

  private void replanPath(Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    PathPlannerPath replanned = currentPath.replan(currentPose, currentSpeeds);
    currentTrajectory = replanned.getTrajectory(currentSpeeds, currentPose.getRotation());
    PathPlannerLogging.logActivePath(replanned);
    PPLibTelemetry.setCurrentPath(replanned);
  }
}
