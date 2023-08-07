package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PurePursuitController;
import com.pathplanner.lib.path.GoalEndState;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPoint;
import com.pathplanner.lib.pathfinding.ADStar;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.util.Units;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PathfindCommand extends Command {
  private final PathPlannerPath targetPath;
  private final Pose2d targetPose;
  private final GoalEndState goalEndState;
  private final PathConstraints constraints;
  private final PurePursuitController controller;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final boolean holonomic;

  private List<PathPoint> pathPoints;

  /**
   * Constructs a new PathfindCommand that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param targetRotation the target rotation of the robot at the end of the path (only applied to
   *     holonomic drive trains)
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param holonomic whether the robot is holonomic or not
   * @param requirements the subsystems required by this command
   */
  public PathfindCommand(
      PathPlannerPath targetPath,
      Rotation2d targetRotation,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      boolean holonomic,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = targetPath;
    this.targetPose = new Pose2d(this.targetPath.getPoint(0).position, targetRotation);
    this.goalEndState =
        new GoalEndState(
            this.targetPath.getGlobalConstraints().getMaxVelocityMps(), targetRotation);
    this.constraints = constraints;

    this.controller =
        new PurePursuitController(
            PathPlannerPath.fromPathPoints(new ArrayList<>(), this.constraints, this.goalEndState),
            holonomic);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
    this.holonomic = holonomic;
  }

  /**
   * Constructs a new PathfindCommand that will generate a path towards the given pose.
   *
   * @param targetPose the pose to pathfind to (rotation will only be taken into account for
   *     holonomic drive trains)
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param holonomic whether the robot is holonomic or not
   * @param requirements the subsystems required by this command
   */
  public PathfindCommand(
      Pose2d targetPose,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      boolean holonomic,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = null;
    this.targetPose = targetPose;
    this.goalEndState = new GoalEndState(goalEndVel, targetPose.getRotation());
    this.constraints = constraints;
    this.controller =
        new PurePursuitController(
            PathPlannerPath.fromPathPoints(new ArrayList<>(), this.constraints, this.goalEndState),
            holonomic);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
    this.holonomic = holonomic;
  }

  /**
   * Constructs a new PathfindCommand that will generate a path towards the given pose and stop.
   *
   * @param targetPose the pose to pathfind to (rotation will only be taken into account for
   *     holonomic drive trains)
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param holonomic whether the robot is holonomic or not
   * @param requirements the subsystems required by this command
   */
  public PathfindCommand(
      Pose2d targetPose,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      boolean holonomic,
      Subsystem... requirements) {
    this(
        targetPose,
        constraints,
        0.0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        holonomic,
        requirements);
  }

  @Override
  public void initialize() {
    pathPoints = new ArrayList<>();

    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    if (holonomic) {
      // Hack to convert robot relative to field relative speeds
      controller.reset(
          ChassisSpeeds.fromFieldRelativeSpeeds(
              speedsSupplier.get(), currentPose.getRotation().unaryMinus()));
    } else {
      controller.reset(speedsSupplier.get());
    }

    ADStar.setStartPos(currentPose.getTranslation());
    ADStar.setGoalPos(targetPose.getTranslation());
  }

  @Override
  public void execute() {
    Pose2d currentPose = poseSupplier.get();

    if (ADStar.isNewPathAvailable()) {
      pathPoints = ADStar.getCurrentPath();
      if (!pathPoints.isEmpty()) {
        pathPoints.get(pathPoints.size() - 1).holonomicRotation = targetPose.getRotation();
        PathPlannerPath path =
            PathPlannerPath.fromPathPoints(pathPoints, constraints, goalEndState);
        controller.setPath(path);
        PathPlannerLogging.logActivePath(path);
        PPLibTelemetry.setCurrentPath(path);
      }
    }

    if (!pathPoints.isEmpty()) {
      ChassisSpeeds currentSpeeds = speedsSupplier.get();

      if (holonomic) {
        // Hack to convert robot relative to field relative speeds
        currentSpeeds =
            ChassisSpeeds.fromFieldRelativeSpeeds(
                currentSpeeds, currentPose.getRotation().unaryMinus());
      }

      ChassisSpeeds targetSpeeds = controller.calculate(currentPose, currentSpeeds);

      PathPlannerLogging.logLookahead(controller.getLastLookahead());
      output.accept(targetSpeeds);

      double actualVel =
          Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);
      double commandedVel =
          Math.hypot(targetSpeeds.vxMetersPerSecond, targetSpeeds.vyMetersPerSecond);

      PPLibTelemetry.setVelocities(
          actualVel,
          commandedVel,
          Units.radiansToDegrees(currentSpeeds.omegaRadiansPerSecond),
          Units.radiansToDegrees(targetSpeeds.omegaRadiansPerSecond));
      PPLibTelemetry.setPathInaccuracy(controller.getLastInaccuracy());
      PPLibTelemetry.setCurrentPose(currentPose);
      PPLibTelemetry.setLookahead(controller.getLastLookahead());
    }
  }

  @Override
  public boolean isFinished() {
    Pose2d currentPose = poseSupplier.get();

    ChassisSpeeds currentSpeeds = speedsSupplier.get();
    if (holonomic) {
      // Hack to convert robot relative to field relative speeds
      currentSpeeds =
          ChassisSpeeds.fromFieldRelativeSpeeds(
              currentSpeeds, currentPose.getRotation().unaryMinus());
    }

    if (targetPath != null) {
      return currentPose.getTranslation().getDistance(targetPath.getPoint(0).position)
          < PurePursuitController.getLookaheadDistance(
              Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond),
              targetPath.getConstraintsForPoint(0));
    } else {
      return controller.isAtGoal(currentPose, currentSpeeds);
    }
  }

  @Override
  public void end(boolean interrupted) {
    if (interrupted || goalEndState.getVelocity() == 0) {
      output.accept(new ChassisSpeeds());
    }
  }
}
