package com.pathplanner.lib.commands;

import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPlannerTrajectory;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.controller.RamseteController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class FollowPathRamsete extends Command {
  private final Timer timer = new Timer();
  private final PathPlannerPath path;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final RamseteController controller;
  private final Consumer<ChassisSpeeds> output;

  private PathPlannerTrajectory generatedTrajectory;
  private ChassisSpeeds lastCommanded;

  public FollowPathRamsete(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      double b,
      double zeta,
      Subsystem... requirements) {
    addRequirements(requirements);

    this.path = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = output;
    this.controller = new RamseteController(b, zeta);
  }

  public FollowPathRamsete(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      Subsystem... requirements) {
    addRequirements(requirements);

    this.path = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = output;
    this.controller = new RamseteController();
  }

  @Override
  public void initialize() {
    Pose2d currentPose = poseSupplier.get();
    lastCommanded = speedsSupplier.get();

    if (currentPose.getTranslation().getDistance(path.getPoint(0).position) >= 0.25
        || Math.hypot(lastCommanded.vxMetersPerSecond, lastCommanded.vyMetersPerSecond) >= 0.25) {
      // Replan path
      PathPlannerPath replanned = path.replan(currentPose, lastCommanded, false);
      generatedTrajectory = new PathPlannerTrajectory(replanned, lastCommanded);
      PathPlannerLogging.logActivePath(replanned);
      PPLibTelemetry.setCurrentPath(replanned);
    } else {
      generatedTrajectory = new PathPlannerTrajectory(path, lastCommanded);
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

    if (path.isReversed()) {
      targetState = targetState.reverse();
    }

    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    PPLibTelemetry.setCurrentPose(currentPose);
    PPLibTelemetry.setTargetPose(targetState.getDifferentialPose());
    PPLibTelemetry.setVelocities(
        currentSpeeds.vxMetersPerSecond,
        lastCommanded.vxMetersPerSecond,
        currentSpeeds.omegaRadiansPerSecond,
        lastCommanded.omegaRadiansPerSecond);
    PathPlannerLogging.logCurrentPose(currentPose);
    PathPlannerLogging.logTargetPose(targetState.getDifferentialPose());

    lastCommanded =
        controller.calculate(
            currentPose,
            targetState.getDifferentialPose(),
            targetState.velocityMps,
            targetState.headingAngularVelocityRps);

    PPLibTelemetry.setPathInaccuracy(
        currentPose.getTranslation().getDistance(targetState.positionMeters));

    output.accept(lastCommanded);
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
