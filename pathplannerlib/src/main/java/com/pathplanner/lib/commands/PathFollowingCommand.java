package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPlannerTrajectory;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PathFollowingCommand extends Command {
  private final Timer timer = new Timer();
  private final PathPlannerPath path;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final PathFollowingController controller;

  private PathPlannerTrajectory generatedTrajectory;

  public PathFollowingCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      PathFollowingController controller,
      Subsystem... requirements) {
    this.path = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = outputRobotRelative;
    this.controller = controller;

    addRequirements(requirements);
  }

  @Override
  public void initialize() {
    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    controller.reset(currentPose, currentSpeeds);

    if (currentPose.getTranslation().getDistance(path.getPoint(0).position) >= 0.25
        || Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond) >= 0.25) {
      // Replan path
      PathPlannerPath replanned = path.replan(currentPose, currentSpeeds);
      generatedTrajectory = new PathPlannerTrajectory(replanned, currentSpeeds);
      PathPlannerLogging.logActivePath(replanned);
      PPLibTelemetry.setCurrentPath(replanned);
    } else {
      generatedTrajectory = new PathPlannerTrajectory(path, currentSpeeds);
      PathPlannerLogging.logActivePath(path);
      PPLibTelemetry.setCurrentPath(path);
    }

    timer.reset();
    timer.start();
  }

  @Override
  public void execute() {
    double currentTime = timer.get();
    PathPlannerTrajectory.State targetState = generatedTrajectory.sample(currentTime);

    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    ChassisSpeeds targetSpeeds = controller.calculateRobotRelativeSpeeds(currentPose, targetState);

    double currentVel =
        Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);

    PPLibTelemetry.setCurrentPose(currentPose);
    PPLibTelemetry.setTargetPose(targetState.getTargetHolonomicPose());
    PathPlannerLogging.logCurrentPose(currentPose);
    PathPlannerLogging.logTargetPose(targetState.getTargetHolonomicPose());
    PPLibTelemetry.setVelocities(
        currentVel,
        targetState.velocityMps,
        currentSpeeds.omegaRadiansPerSecond,
        targetSpeeds.omegaRadiansPerSecond);
    PPLibTelemetry.setPathInaccuracy(controller.getPositionalError());

    output.accept(targetSpeeds);
  }

  @Override
  public boolean isFinished() {
    return timer.hasElapsed(generatedTrajectory.getTotalTimeSeconds());
  }

  @Override
  public void end(boolean interrupted) {
    timer.stop();

    // Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
    // the command to smoothly transition into some auto-alignment routine
    if (!interrupted && path.getGoalEndState().getVelocity() < 0.1) {
      output.accept(new ChassisSpeeds());
    }
  }
}
