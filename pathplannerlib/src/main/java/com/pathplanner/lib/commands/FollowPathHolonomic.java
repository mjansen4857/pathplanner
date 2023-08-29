package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.HolonomicDriveController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPlannerTrajectory;
import com.pathplanner.lib.util.HolonomicPathFollowerConfig;
import com.pathplanner.lib.util.PIDConstants;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class FollowPathHolonomic extends Command {
  private final Timer timer = new Timer();
  private final PathPlannerPath path;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final HolonomicDriveController controller;
  private final Consumer<ChassisSpeeds> output;

  private PathPlannerTrajectory generatedTrajectory;

  public FollowPathHolonomic(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxModuleSpeed,
      double driveBaseRadius,
      double period,
      Subsystem... requirements) {
    this.path = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.controller =
        new HolonomicDriveController(
            translationConstants, rotationConstants, period, maxModuleSpeed, driveBaseRadius);
    this.output = outputRobotRelative;

    addRequirements(requirements);
  }

  public FollowPathHolonomic(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxModuleSpeed,
      double driveBaseRadius,
      Subsystem... requirements) {
    this(
        path,
        poseSupplier,
        speedsSupplier,
        outputRobotRelative,
        translationConstants,
        rotationConstants,
        maxModuleSpeed,
        driveBaseRadius,
        0.02,
        requirements);
  }

  public FollowPathHolonomic(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      HolonomicPathFollowerConfig config,
      Subsystem... requirements) {
    this(
        path,
        poseSupplier,
        speedsSupplier,
        outputRobotRelative,
        config.translationConstants,
        config.rotationConstants,
        config.maxModuleSpeed,
        config.driveBaseRadius,
        config.period,
        requirements);
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

    ChassisSpeeds targetSpeeds = controller.calculate(currentPose, targetState);

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
  public void end(boolean interrupted) {
    timer.stop();

    // Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
    // the command to smoothly transition into some auto-alignment routine
    if (!interrupted && path.getGoalEndState().getVelocity() < 0.1) {
      output.accept(new ChassisSpeeds());
    }
  }

  @Override
  public boolean isFinished() {
    return timer.hasElapsed(generatedTrajectory.getTotalTimeSeconds());
  }
}
