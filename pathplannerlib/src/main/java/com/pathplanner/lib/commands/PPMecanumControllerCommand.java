// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

package com.pathplanner.lib.commands;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.PathPlannerTrajectory.PathPlannerState;
import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import com.pathplanner.lib.server.PathPlannerServer;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.MecanumDriveKinematics;
import edu.wpi.first.math.kinematics.MecanumDriveWheelSpeeds;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj.smartdashboard.Field2d;
import edu.wpi.first.wpilibj.smartdashboard.SmartDashboard;
import edu.wpi.first.wpilibj2.command.*;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Custom PathPlanner version of MecanumControllerCommand */
public class PPMecanumControllerCommand extends CommandBase {
  private final Timer timer = new Timer();
  private final PathPlannerTrajectory trajectory;
  private final Supplier<Pose2d> poseSupplier;
  private final MecanumDriveKinematics kinematics;
  private final PPHolonomicDriveController controller;
  private final double maxWheelVelocityMetersPerSecond;
  private final Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds;
  private final Consumer<ChassisSpeeds> outputChassisSpeeds;
  private final boolean useKinematics;
  private final boolean useAllianceColor;
  private final Field2d field = new Field2d();

  private PathPlannerTrajectory transformedTrajectory;

  /**
   * Constructs a new PPMecanumControllerCommand that when executed will follow the provided
   * trajectory. The user should implement a velocity PID on the desired output wheel velocities.
   *
   * <p>Note: The controllers will *not* set the output to zero upon completion of the path - this
   * is left to the user, since it is not appropriate for paths with non-stationary end-states.
   *
   * @param trajectory The Pathplanner trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param xController The Trajectory Tracker PID controller for the robot's x position.
   * @param yController The Trajectory Tracker PID controller for the robot's y position.
   * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
   * @param outputChassisSpeeds A consumer for a ChassisSpeeds object containing the output speeds.
   * @param useAllianceColor Should the path states be automatically transformed based on alliance
   *     color? In order for this to work properly, you MUST create your path on the blue side of
   *     the field.
   * @param requirements The subsystems to require.
   */
  public PPMecanumControllerCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      PIDController xController,
      PIDController yController,
      PIDController rotationController,
      Consumer<ChassisSpeeds> outputChassisSpeeds,
      boolean useAllianceColor,
      Subsystem... requirements) {
    this.trajectory = trajectory;
    this.poseSupplier = poseSupplier;
    this.kinematics = null;
    this.controller = new PPHolonomicDriveController(xController, yController, rotationController);
    this.maxWheelVelocityMetersPerSecond = 0;
    this.outputWheelSpeeds = null;
    this.outputChassisSpeeds = outputChassisSpeeds;
    this.useKinematics = false;
    this.useAllianceColor = useAllianceColor;

    addRequirements(requirements);

    if (useAllianceColor && trajectory.fromGUI && trajectory.getInitialPose().getX() > 8.27) {
      DriverStation.reportWarning(
          "You have constructed a path following command that will automatically transform path states depending"
              + " on the alliance color, however, it appears this path was created on the red side of the field"
              + " instead of the blue side. This is likely an error.",
          false);
    }
  }

  /**
   * Constructs a new PPMecanumControllerCommand that when executed will follow the provided
   * trajectory. The user should implement a velocity PID on the desired output wheel velocities.
   *
   * <p>Note: The controllers will *not* set the output to zero upon completion of the path - this
   * is left to the user, since it is not appropriate for paths with non-stationary end-states.
   *
   * @param trajectory The Pathplanner trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param xController The Trajectory Tracker PID controller for the robot's x position.
   * @param yController The Trajectory Tracker PID controller for the robot's y position.
   * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
   * @param outputChassisSpeeds A consumer for a ChassisSpeeds object containing the output speeds.
   * @param requirements The subsystems to require.
   */
  public PPMecanumControllerCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      PIDController xController,
      PIDController yController,
      PIDController rotationController,
      Consumer<ChassisSpeeds> outputChassisSpeeds,
      Subsystem... requirements) {
    this(
        trajectory,
        poseSupplier,
        xController,
        yController,
        rotationController,
        outputChassisSpeeds,
        true,
        requirements);
  }

  /**
   * Constructs a new PPMecanumControllerCommand that when executed will follow the provided
   * trajectory. The user should implement a velocity PID on the desired output wheel velocities.
   *
   * <p>Note: The controllers will *not* set the output to zero upon completion of the path - this
   * is left to the user, since it is not appropriate for paths with non-stationary end-states.
   *
   * @param trajectory The Pathplanner trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param xController The Trajectory Tracker PID controller for the robot's x position.
   * @param yController The Trajectory Tracker PID controller for the robot's y position.
   * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
   * @param maxWheelVelocityMetersPerSecond The maximum velocity of a drivetrain wheel.
   * @param outputWheelSpeeds A MecanumDriveWheelSpeeds object containing the output wheel speeds.
   * @param useAllianceColor Should the path states be automatically transformed based on alliance
   *     color? In order for this to work properly, you MUST create your path on the blue side of
   *     the field.
   * @param requirements The subsystems to require.
   */
  public PPMecanumControllerCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      MecanumDriveKinematics kinematics,
      PIDController xController,
      PIDController yController,
      PIDController rotationController,
      double maxWheelVelocityMetersPerSecond,
      Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds,
      boolean useAllianceColor,
      Subsystem... requirements) {
    this.trajectory = trajectory;
    this.poseSupplier = poseSupplier;
    this.kinematics = kinematics;
    this.controller = new PPHolonomicDriveController(xController, yController, rotationController);
    this.maxWheelVelocityMetersPerSecond = maxWheelVelocityMetersPerSecond;
    this.outputWheelSpeeds = outputWheelSpeeds;
    this.outputChassisSpeeds = null;
    this.useKinematics = true;
    this.useAllianceColor = useAllianceColor;

    addRequirements(requirements);

    if (useAllianceColor && trajectory.fromGUI && trajectory.getInitialPose().getX() > 8.27) {
      DriverStation.reportWarning(
          "You have constructed a path following command that will automatically transform path states depending"
              + " on the alliance color, however, it appears this path was created on the red side of the field"
              + " instead of the blue side. This is likely an error.",
          false);
    }
  }

  /**
   * Constructs a new PPMecanumControllerCommand that when executed will follow the provided
   * trajectory. The user should implement a velocity PID on the desired output wheel velocities.
   *
   * <p>Note: The controllers will *not* set the output to zero upon completion of the path - this
   * is left to the user, since it is not appropriate for paths with non-stationary end-states.
   *
   * @param trajectory The Pathplanner trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param xController The Trajectory Tracker PID controller for the robot's x position.
   * @param yController The Trajectory Tracker PID controller for the robot's y position.
   * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
   * @param maxWheelVelocityMetersPerSecond The maximum velocity of a drivetrain wheel.
   * @param outputWheelSpeeds A MecanumDriveWheelSpeeds object containing the output wheel speeds.
   * @param requirements The subsystems to require.
   */
  public PPMecanumControllerCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      MecanumDriveKinematics kinematics,
      PIDController xController,
      PIDController yController,
      PIDController rotationController,
      double maxWheelVelocityMetersPerSecond,
      Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds,
      Subsystem... requirements) {
    this(
        trajectory,
        poseSupplier,
        kinematics,
        xController,
        yController,
        rotationController,
        maxWheelVelocityMetersPerSecond,
        outputWheelSpeeds,
        true,
        requirements);
  }

  @Override
  public void initialize() {
    if (useAllianceColor && trajectory.fromGUI) {
      transformedTrajectory =
          PathPlannerTrajectory.transformTrajectoryForAlliance(
              trajectory, DriverStation.getAlliance());
    } else {
      transformedTrajectory = trajectory;
    }

    SmartDashboard.putData("PPMecanumControllerCommand_field", this.field);
    this.field.getObject("traj").setTrajectory(transformedTrajectory);

    this.timer.reset();
    this.timer.start();

    PathPlannerServer.sendActivePath(transformedTrajectory.getStates());
  }

  @Override
  public void execute() {
    double currentTime = this.timer.get();
    PathPlannerState desiredState = (PathPlannerState) transformedTrajectory.sample(currentTime);

    Pose2d currentPose = this.poseSupplier.get();
    this.field.setRobotPose(currentPose);
    PathPlannerServer.sendPathFollowingData(
        new Pose2d(desiredState.poseMeters.getTranslation(), desiredState.holonomicRotation),
        currentPose);

    SmartDashboard.putNumber(
        "PPMecanumControllerCommand_xError", currentPose.getX() - desiredState.poseMeters.getX());
    SmartDashboard.putNumber(
        "PPMecanumControllerCommand_yError", currentPose.getY() - desiredState.poseMeters.getY());
    SmartDashboard.putNumber(
        "PPMecanumControllerCommand_rotationError",
        currentPose.getRotation().getRadians() - desiredState.holonomicRotation.getRadians());

    ChassisSpeeds targetChassisSpeeds = this.controller.calculate(currentPose, desiredState);

    if (this.useKinematics) {
      MecanumDriveWheelSpeeds targetWheelSpeeds =
          this.kinematics.toWheelSpeeds(targetChassisSpeeds);

      targetWheelSpeeds.desaturate(this.maxWheelVelocityMetersPerSecond);

      this.outputWheelSpeeds.accept(targetWheelSpeeds);
    } else {
      this.outputChassisSpeeds.accept(targetChassisSpeeds);
    }
  }

  @Override
  public void end(boolean interrupted) {
    this.timer.stop();

    if (interrupted) {
      if (this.useKinematics) {
        this.outputWheelSpeeds.accept(new MecanumDriveWheelSpeeds(0, 0, 0, 0));
      } else {
        this.outputChassisSpeeds.accept(new ChassisSpeeds());
      }
    }
  }

  @Override
  public boolean isFinished() {
    return this.timer.hasElapsed(transformedTrajectory.getTotalTimeSeconds());
  }
}
