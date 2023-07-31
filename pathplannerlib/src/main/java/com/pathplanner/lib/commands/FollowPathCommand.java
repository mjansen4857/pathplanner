package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PurePursuitController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.util.Units;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class FollowPathCommand extends CommandBase {
  private final PathPlannerPath path;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final PurePursuitController controller;

  private boolean finished;

  public FollowPathCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> fieldRelativeOutput,
      Subsystem... requirements) {
    addRequirements(requirements);

    this.path = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = fieldRelativeOutput;
    this.controller = new PurePursuitController(path);
    this.finished = false;
  }

  @Override
  public void initialize() {
    finished = false;

    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    // Hack to convert robot relative to field relative speeds
    controller.reset(
        ChassisSpeeds.fromFieldRelativeSpeeds(
            speedsSupplier.get(), currentPose.getRotation().unaryMinus()));

    PathPlannerLogging.logActivePath(path);
    PPLibTelemetry.setCurrentPath(path);
  }

  @Override
  public void execute() {
    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    // Hack to convert robot relative to field relative speeds
    ChassisSpeeds currentFieldRelativeSpeeds =
        ChassisSpeeds.fromFieldRelativeSpeeds(
            speedsSupplier.get(), currentPose.getRotation().unaryMinus());

    ChassisSpeeds targetSpeeds = controller.calculate(currentPose, currentFieldRelativeSpeeds);

    if (targetSpeeds != null) {
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

    finished = controller.isAtGoal(currentPose, currentFieldRelativeSpeeds);
  }

  @Override
  public boolean isFinished() {
    return finished;
  }

  @Override
  public void end(boolean interrupted) {
    if (interrupted || path.getGoalEndState().getVelocity() == 0) {
      output.accept(new ChassisSpeeds());
    }
  }
}
