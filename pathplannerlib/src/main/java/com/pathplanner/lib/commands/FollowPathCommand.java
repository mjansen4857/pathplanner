package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPlannerTrajectory;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import com.pathplanner.lib.util.ReplanningConfig;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Base command for following a path */
public class FollowPathCommand extends Command {
  private final Timer timer = new Timer();
  private final PathPlannerPath path;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final PathFollowingController controller;
  private final ReplanningConfig replanningConfig;

  private PathPlannerTrajectory generatedTrajectory;

  /**
   * Construct a base path following command
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param outputRobotRelative Function that will apply the robot-relative output speeds of this
   *     command
   * @param controller Path following controller that will be used to follow the path
   * @param replanningConfig Path replanning configuration
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
  public FollowPathCommand(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      PathFollowingController controller,
      ReplanningConfig replanningConfig,
      Subsystem... requirements) {
    this.path = path;
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.output = outputRobotRelative;
    this.controller = controller;
    this.replanningConfig = replanningConfig;

    addRequirements(requirements);
  }

  @Override
  public void initialize() {
    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    controller.reset(currentPose, currentSpeeds);

    if (replanningConfig.enableInitialReplanning
        && (currentPose.getTranslation().getDistance(path.getPoint(0).position) >= 0.25
            || Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond)
                >= 0.25)) {
      replanPath(currentPose, currentSpeeds);
    } else {
      generatedTrajectory =
          new PathPlannerTrajectory(path, currentSpeeds, currentPose.getRotation());
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
    if (!controller.isHolonomic() && path.isReversed()) {
      targetState = targetState.reverse();
    }

    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    if (replanningConfig.enableDynamicReplanning) {
      double previousError = Math.abs(controller.getPositionalError());
      double currentError = currentPose.getTranslation().getDistance(targetState.positionMeters);

      if (currentError >= replanningConfig.dynamicReplanningTotalErrorThreshold
          || currentError - previousError
              >= replanningConfig.dynamicReplanningErrorSpikeThreshold) {
        replanPath(currentPose, currentSpeeds);
        timer.reset();
        targetState = generatedTrajectory.sample(0);
      }
    }

    ChassisSpeeds targetSpeeds = controller.calculateRobotRelativeSpeeds(currentPose, targetState);

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

  private void replanPath(Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    PathPlannerPath replanned = path.replan(currentPose, currentSpeeds);
    generatedTrajectory =
        new PathPlannerTrajectory(replanned, currentSpeeds, currentPose.getRotation());
    PathPlannerLogging.logActivePath(replanned);
    PPLibTelemetry.setCurrentPath(replanned);
  }
}
