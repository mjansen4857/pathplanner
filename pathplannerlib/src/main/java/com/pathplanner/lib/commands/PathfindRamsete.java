package com.pathplanner.lib.commands;

import com.pathplanner.lib.path.GoalEndState;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPlannerTrajectory;
import com.pathplanner.lib.pathfinding.ADStar;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.controller.RamseteController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.util.Units;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.Collections;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PathfindRamsete extends Command {
  private final PathPlannerPath targetPath;
  private final Translation2d targetPosition;
  private final GoalEndState goalEndState;
  private final PathConstraints constraints;
  private final RamseteController controller;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final Timer timer = new Timer();

  private PathPlannerTrajectory currentTrajectory;

  /**
   * Constructs a new PathfindRamsete command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (robot relative)
   * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
   *     aggressive like a proportional term.
   * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
   *     more damping in response.
   * @param requirements the subsystems required by this command
   */
  public PathfindRamsete(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double b,
      double zeta,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = targetPath;
    this.targetPosition = this.targetPath.getPoint(0).position;
    this.goalEndState =
        new GoalEndState(
            this.targetPath.getGlobalConstraints().getMaxVelocityMps(), new Rotation2d());
    this.constraints = constraints;
    this.controller = new RamseteController(b, zeta);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
  }

  /**
   * Constructs a new PathfindRamsete command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (robot relative)
   * @param requirements the subsystems required by this command
   */
  public PathfindRamsete(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = targetPath;
    this.targetPosition = this.targetPath.getPoint(0).position;
    this.goalEndState =
        new GoalEndState(
            this.targetPath.getGlobalConstraints().getMaxVelocityMps(), new Rotation2d());
    this.constraints = constraints;
    this.controller = new RamseteController();
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
  }

  /**
   * Constructs a new PathfindRamsete command that will generate a path towards the given position.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
   *     aggressive like a proportional term.
   * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
   *     more damping in response.
   * @param requirements the subsystems required by this command
   */
  public PathfindRamsete(
      Translation2d targetPosition,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double b,
      double zeta,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = null;
    this.targetPosition = targetPosition;
    this.goalEndState = new GoalEndState(goalEndVel, new Rotation2d());
    this.constraints = constraints;
    this.controller = new RamseteController(b, zeta);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
  }

  /**
   * Constructs a new PathfindRamsete command that will generate a path towards the given position.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param requirements the subsystems required by this command
   */
  public PathfindRamsete(
      Translation2d targetPosition,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = null;
    this.targetPosition = targetPosition;
    this.goalEndState = new GoalEndState(goalEndVel, new Rotation2d());
    this.constraints = constraints;
    this.controller = new RamseteController();
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
  }

  /**
   * Constructs a new PathfindRamsete command that will generate a path towards the given position
   * and stop.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
   *     aggressive like a proportional term.
   * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
   *     more damping in response.
   * @param requirements the subsystems required by this command
   */
  public PathfindRamsete(
      Translation2d targetPosition,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double b,
      double zeta,
      Subsystem... requirements) {
    this(
        targetPosition,
        constraints,
        0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        b,
        zeta,
        requirements);
  }

  /**
   * Constructs a new PathfindRamsete command that will generate a path towards the given position
   * and stop.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param requirements the subsystems required by this command
   */
  public PathfindRamsete(
      Translation2d targetPosition,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Subsystem... requirements) {
    this(
        targetPosition,
        constraints,
        0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        requirements);
  }

  @Override
  public void initialize() {
    currentTrajectory = null;

    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    if (ADStar.getGridPos(currentPose.getTranslation()).equals(ADStar.getGridPos(targetPosition))) {
      this.cancel();
    } else {
      ADStar.setStartPos(currentPose.getTranslation());
      ADStar.setGoalPos(targetPosition);
    }
  }

  @Override
  public void execute() {
    Pose2d currentPose = poseSupplier.get();
    ChassisSpeeds currentSpeeds = speedsSupplier.get();

    PathPlannerLogging.logCurrentPose(currentPose);
    PPLibTelemetry.setCurrentPose(currentPose);

    if (ADStar.isNewPathAvailable()) {
      List<Translation2d> bezierPoints = ADStar.getCurrentPath();

      if (bezierPoints.size() >= 4) {
        PathPlannerPath path =
            new PathPlannerPath(
                bezierPoints,
                Collections.emptyList(),
                Collections.emptyList(),
                Collections.emptyList(),
                constraints,
                goalEndState,
                false);

        if (currentPose.getTranslation().getDistance(path.getPoint(0).position) <= 0.25
            || Math.abs(currentSpeeds.vxMetersPerSecond) > 0.1) {
          currentTrajectory = new PathPlannerTrajectory(path, currentSpeeds);

          PathPlannerLogging.logActivePath(path);
          PPLibTelemetry.setCurrentPath(path);
        } else {
          PathPlannerPath replanned = path.replan(currentPose, currentSpeeds);
          currentTrajectory = new PathPlannerTrajectory(replanned, currentSpeeds);

          PathPlannerLogging.logActivePath(replanned);
          PPLibTelemetry.setCurrentPath(replanned);
        }

        timer.reset();
        timer.start();
      }
    }

    if (currentTrajectory != null) {
      PathPlannerTrajectory.State targetState = currentTrajectory.sample(timer.get());
      ChassisSpeeds targetSpeeds =
          controller.calculate(
              currentPose,
              targetState.getDifferentialPose(),
              targetState.velocityMps,
              targetState.headingAngularVelocityRps);

      PathPlannerLogging.logTargetPose(targetState.getTargetHolonomicPose());
      output.accept(targetSpeeds);

      PPLibTelemetry.setVelocities(
          currentSpeeds.vxMetersPerSecond,
          targetSpeeds.vxMetersPerSecond,
          Units.radiansToDegrees(currentSpeeds.omegaRadiansPerSecond),
          Units.radiansToDegrees(targetSpeeds.omegaRadiansPerSecond));
      PPLibTelemetry.setPathInaccuracy(
          currentPose.getTranslation().getDistance(targetState.positionMeters));
      PPLibTelemetry.setTargetPose(targetState.getTargetHolonomicPose());
    }
  }

  @Override
  public boolean isFinished() {
    if (targetPath != null) {
      Pose2d currentPose = poseSupplier.get();
      ChassisSpeeds currentSpeeds = speedsSupplier.get();

      double currentVel = currentSpeeds.vxMetersPerSecond;
      double stoppingDistance =
          Math.pow(currentVel, 2) / (2 * constraints.getMaxAccelerationMpsSq());

      return currentPose.getTranslation().getDistance(targetPath.getPoint(0).position)
          <= stoppingDistance;
    }

    if (currentTrajectory != null) {
      return timer.hasElapsed(currentTrajectory.getTotalTimeSeconds());
    }

    return false;
  }

  @Override
  public void end(boolean interrupted) {
    // Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
    // the command to smoothly transition into some auto-alignment routine
    if (!interrupted && goalEndState.getVelocity() < 0.1) {
      output.accept(new ChassisSpeeds());
    }

    timer.stop();
  }
}
