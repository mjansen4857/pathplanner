package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PurePursuitController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.util.Units;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class DifferentialFollowPathCommand extends Command {
  private final PathPlannerPath path;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final PurePursuitController controller;

  private boolean finished;

  public DifferentialFollowPathCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentSpeeds,
      Consumer<ChassisSpeeds> output,
      Subsystem... requirements) {
    addRequirements(requirements);

    this.path = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentSpeeds;
    this.output = output;
    this.controller = new PurePursuitController(path, false);
    this.finished = false;
  }

  @Override
  public void initialize() {
    finished = false;

    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    // Hack to convert robot relative to field relative speeds
    controller.reset(speedsSupplier.get());

    PathPlannerLogging.logActivePath(path);
    PPLibTelemetry.setCurrentPath(path);
  }

  @Override
  public void execute() {
    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    // Hack to convert robot relative to field relative speeds
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    ChassisSpeeds targetSpeeds = controller.calculate(currentPose, currentSpeeds);

    if (targetSpeeds != null) {
      PathPlannerLogging.logLookahead(controller.getLastLookahead());
      output.accept(targetSpeeds);

      double actualVel = currentSpeeds.vxMetersPerSecond;
      double commandedVel = targetSpeeds.vxMetersPerSecond;

      PPLibTelemetry.setVelocities(
          actualVel,
          commandedVel,
          Units.radiansToDegrees(currentSpeeds.omegaRadiansPerSecond),
          Units.radiansToDegrees(targetSpeeds.omegaRadiansPerSecond));
      PPLibTelemetry.setPathInaccuracy(controller.getLastInaccuracy());
      PPLibTelemetry.setCurrentPose(currentPose);
      PPLibTelemetry.setLookahead(controller.getLastLookahead());
    }

    finished = controller.isAtGoal(currentPose, currentSpeeds);
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
