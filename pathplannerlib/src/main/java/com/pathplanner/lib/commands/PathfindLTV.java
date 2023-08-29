package com.pathplanner.lib.commands;

import com.pathplanner.lib.path.GoalEndState;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPlannerTrajectory;
import com.pathplanner.lib.pathfinding.ADStar;
import com.pathplanner.lib.util.PPLibTelemetry;
import com.pathplanner.lib.util.PathPlannerLogging;
import edu.wpi.first.math.Vector;
import edu.wpi.first.math.controller.LTVUnicycleController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.numbers.N2;
import edu.wpi.first.math.numbers.N3;
import edu.wpi.first.math.util.Units;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.Collections;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PathfindLTV extends Command {
  private final PathPlannerPath targetPath;
  private Translation2d targetPosition;
  private final GoalEndState goalEndState;
  private final PathConstraints constraints;
  private final LTVUnicycleController controller;
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<ChassisSpeeds> speedsSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final Timer timer = new Timer();

  private PathPlannerTrajectory currentTrajectory;

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (robot relative)
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Vector<N3> qelems,
      Vector<N2> relems,
      double dt,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = targetPath;
    this.targetPosition = this.targetPath.getPoint(0).position;
    this.goalEndState =
        new GoalEndState(
            this.targetPath.getGlobalConstraints().getMaxVelocityMps(), new Rotation2d());
    this.constraints = constraints;
    this.controller = new LTVUnicycleController(qelems, relems, dt);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given path.
   *
   * @param targetPath the path to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (robot relative)
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      PathPlannerPath targetPath,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double dt,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = targetPath;
    this.targetPosition = this.targetPath.getPoint(0).position;
    this.goalEndState =
        new GoalEndState(
            this.targetPath.getGlobalConstraints().getMaxVelocityMps(), new Rotation2d());
    this.constraints = constraints;
    this.controller = new LTVUnicycleController(dt);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given position.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      Translation2d targetPosition,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Vector<N3> qelems,
      Vector<N2> relems,
      double dt,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = null;
    this.targetPosition = targetPosition;
    this.goalEndState = new GoalEndState(goalEndVel, new Rotation2d());
    this.constraints = constraints;
    this.controller = new LTVUnicycleController(qelems, relems, dt);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given position.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param goalEndVel The goal end velocity when reaching the given pose
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      Translation2d targetPosition,
      PathConstraints constraints,
      double goalEndVel,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double dt,
      Subsystem... requirements) {
    addRequirements(requirements);

    ADStar.ensureInitialized();

    this.targetPath = null;
    this.targetPosition = targetPosition;
    this.goalEndState = new GoalEndState(goalEndVel, new Rotation2d());
    this.constraints = constraints;
    this.controller = new LTVUnicycleController(dt);
    this.poseSupplier = poseSupplier;
    this.speedsSupplier = currentRobotRelativeSpeeds;
    this.output = output;
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given position and
   * stop.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      Translation2d targetPosition,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      Vector<N3> qelems,
      Vector<N2> relems,
      double dt,
      Subsystem... requirements) {
    this(
        targetPosition,
        constraints,
        0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        qelems,
        relems,
        dt,
        requirements);
  }

  /**
   * Constructs a new PathfindLTV command that will generate a path towards the given position and
   * stop.
   *
   * @param targetPosition the position to pathfind to
   * @param constraints the path constraints to use while pathfinding
   * @param poseSupplier a supplier for the robot's current pose
   * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
   * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
   *     differential)
   * @param dt Period of the robot control loop in seconds (default 0.02)
   * @param requirements the subsystems required by this command
   */
  public PathfindLTV(
      Translation2d targetPosition,
      PathConstraints constraints,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> currentRobotRelativeSpeeds,
      Consumer<ChassisSpeeds> output,
      double dt,
      Subsystem... requirements) {
    this(
        targetPosition,
        constraints,
        0,
        poseSupplier,
        currentRobotRelativeSpeeds,
        output,
        dt,
        requirements);
  }

  @Override
  public void initialize() {
    currentTrajectory = null;

    Pose2d currentPose = poseSupplier.get();
    PathPlannerLogging.logCurrentPose(currentPose);

    if (targetPath != null) {
      targetPosition = this.targetPath.getPoint(0).position;
    }

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
