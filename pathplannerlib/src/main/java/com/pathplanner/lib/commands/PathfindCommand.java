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
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PathfindCommand extends CommandBase {
  private final PathPlannerPath targetPath;
  private final Pose2d targetPose;
  private final GoalEndState goalEndState;
  private final PathConstraints constraints;
  private final PurePursuitController controller;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;

  private List<PathPoint> pathPoints;
  //  private Pose2d currentObsPose;

  public PathfindCommand(
      PathPlannerPath targetPath,
      Rotation2d targetRotation,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> fieldRelativeOutput,
      Subsystem... requirements) {
    addRequirements(requirements);

    this.targetPath = targetPath;
    this.targetPose = new Pose2d(this.targetPath.getPoint(0).position, targetRotation);
    this.goalEndState =
        new GoalEndState(
            this.targetPath.getGlobalConstraints().getMaxVelocityMps(), targetRotation);
    this.constraints = constraints;

    this.controller =
        new PurePursuitController(
            PathPlannerPath.fromPathPoints(new ArrayList<>(), this.constraints, this.goalEndState));
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = fieldRelativeOutput;
  }

  public PathfindCommand(
      Pose2d targetPose,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> fieldRelativeOutput,
      Subsystem... requirements) {
    addRequirements(requirements);

    this.targetPath = null;
    this.targetPose = targetPose;
    this.goalEndState = new GoalEndState(goalEndVel, targetPose.getRotation());
    this.constraints = constraints;
    this.controller =
        new PurePursuitController(
            PathPlannerPath.fromPathPoints(new ArrayList<>(), this.constraints, this.goalEndState));
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = fieldRelativeOutput;
  }

  public PathfindCommand(
      Pose2d targetPose,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> fieldRelativeOutput,
      Subsystem... requirements) {
    this(
        targetPose,
        constraints,
        0.0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        fieldRelativeOutput,
        requirements);
  }

  @Override
  public void initialize() {
    pathPoints = new ArrayList<>();

    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    // Hack to convert robot relative to field relative speeds
    controller.reset(
        ChassisSpeeds.fromFieldRelativeSpeeds(
            speedsSupplier.get(), currentPose.getRotation().unaryMinus()));

    ADStar.setStartPos(currentPose.getTranslation());
    ADStar.setGoalPos(targetPose.getTranslation());
  }

  @Override
  public void execute() {
    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

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
      // Hack to convert robot relative to field relative speeds
      ChassisSpeeds currentFieldRelativeSpeeds =
          ChassisSpeeds.fromFieldRelativeSpeeds(
              speedsSupplier.get(), currentPose.getRotation().unaryMinus());

      ChassisSpeeds targetSpeeds = controller.calculate(currentPose, currentFieldRelativeSpeeds);

      if (targetSpeeds == null) {
        // Could not find lookahead for path, set the start pos to current pos
        ADStar.setStartPos(currentPose.getTranslation());
        return;
      }

      PathPlannerLogging.logLookahead(controller.getLastLookahead());
      output.accept(targetSpeeds);

      double actualVel =
          Math.hypot(
              currentFieldRelativeSpeeds.vxMetersPerSecond,
              currentFieldRelativeSpeeds.vyMetersPerSecond);
      double commandedVel =
          Math.hypot(targetSpeeds.vxMetersPerSecond, targetSpeeds.vyMetersPerSecond);

      PPLibTelemetry.setVelocities(
          actualVel,
          commandedVel,
          Units.radiansToDegrees(currentFieldRelativeSpeeds.omegaRadiansPerSecond),
          Units.radiansToDegrees(targetSpeeds.omegaRadiansPerSecond));
      PPLibTelemetry.setPathInaccuracy(controller.getLastInaccuracy());
      PPLibTelemetry.setCurrentPose(currentPose);
      PPLibTelemetry.setLookahead(controller.getLastLookahead());
    }
  }

  @Override
  public boolean isFinished() {
    Pose2d currentPose = poseSupplier.get();
    // Hack to convert robot relative to field relative speeds
    ChassisSpeeds currentSpeeds =
        ChassisSpeeds.fromFieldRelativeSpeeds(
            speedsSupplier.get(), currentPose.getRotation().unaryMinus());

    if (targetPath != null) {
      return currentPose.getTranslation().getDistance(targetPath.getPoint(0).position)
          < controller.getLookaheadDistance(
              Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond),
              targetPath.getConstraintsForPoint(0));
    } else {
      return controller.isAtGoal(currentPose, currentSpeeds);
    }
  }

  @Override
  public void end(boolean interrupted) {
    if (interrupted) {
      output.accept(new ChassisSpeeds());
    }
  }
}
