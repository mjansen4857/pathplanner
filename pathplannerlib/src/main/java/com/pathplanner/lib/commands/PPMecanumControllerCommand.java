// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

package com.pathplanner.lib.commands;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.PathPlannerTrajectory.PathPlannerState;
import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.MecanumDriveKinematics;
import edu.wpi.first.math.kinematics.MecanumDriveWheelSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj.smartdashboard.Field2d;
import edu.wpi.first.wpilibj.smartdashboard.SmartDashboard;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.function.Consumer;
import java.util.function.Supplier;

/**
 * Custom PathPlanner version of MecanumControllerCommand
 */
public class PPMecanumControllerCommand extends CommandBase {
  private final Timer timer = new Timer();
  private final PathPlannerTrajectory trajectory;
  private final Supplier<Pose2d> poseSupplier;
  private final MecanumDriveKinematics kinematics;
  private final PPHolonomicDriveController controller;
  private final double maxWheelVelocityMetersPerSecond;
  private final Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds;
  private final HashMap<String, Command> eventMap;
  private final Field2d field = new Field2d();

  private ArrayList<PathPlannerTrajectory.EventMarker> unpassedMarkers;

  /**
   * Constructs a new PPMecanumControllerCommand that when executed will follow the provided
   * trajectory. The user should implement a velocity PID on the desired output wheel velocities.
   *
   * <p>Note: The controllers will *not* set the outputVolts to zero upon completion of the path -
   * this is left to the user, since it is not appropriate for paths with non-stationary end-states.
   *
   * @param trajectory The Pathplanner trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes to
   *     provide this.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param xController The Trajectory Tracker PID controller for the robot's x position.
   * @param yController The Trajectory Tracker PID controller for the robot's y position.
   * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
   * @param maxWheelVelocityMetersPerSecond The maximum velocity of a drivetrain wheel.
   * @param outputWheelSpeeds A MecanumDriveWheelSpeeds object containing the output wheel speeds.
   * @param eventMap           Map of event marker names to the commands that should run when reaching that marker.
   *                           This SHOULD NOT contain any commands requiring the same subsystems as this command, or it will be interrupted
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
      HashMap<String, Command> eventMap,
      Subsystem... requirements) {
    this.trajectory = trajectory;
    this.poseSupplier = poseSupplier;
    this.kinematics = kinematics;
    this.controller = new PPHolonomicDriveController(xController, yController, rotationController);
    this.maxWheelVelocityMetersPerSecond = maxWheelVelocityMetersPerSecond;
    this.outputWheelSpeeds = outputWheelSpeeds;
    this.eventMap = eventMap;

    addRequirements(requirements);
  }

  /**
   * Constructs a new PPMecanumControllerCommand that when executed will follow the provided
   * trajectory. The user should implement a velocity PID on the desired output wheel velocities.
   *
   * <p>Note: The controllers will *not* set the outputVolts to zero upon completion of the path -
   * this is left to the user, since it is not appropriate for paths with non-stationary end-states.
   *
   * @param trajectory The Pathplanner trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes to
   *     provide this.
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
    this(trajectory, poseSupplier, kinematics, xController, yController, rotationController, maxWheelVelocityMetersPerSecond, outputWheelSpeeds, new HashMap<>(), requirements);
  }

  @Override
  public void initialize() {
    this.unpassedMarkers = new ArrayList<>();
    this.unpassedMarkers.addAll(this.trajectory.getMarkers());

    SmartDashboard.putData("PPMecanumControllerCommand_field", this.field);
    this.field.getObject("traj").setTrajectory(this.trajectory);

    this.timer.reset();
    this.timer.start();
  }

  @Override
  public void execute() {
    double currentTime = this.timer.get();
    PathPlannerState desiredState = (PathPlannerState) this.trajectory.sample(currentTime);

    Pose2d currentPose = this.poseSupplier.get();
    this.field.setRobotPose(currentPose);

    SmartDashboard.putNumber("PPMecanumControllerCommand_xError", currentPose.getX() - desiredState.poseMeters.getX());
    SmartDashboard.putNumber("PPMecanumControllerCommand_yError", currentPose.getY() - desiredState.poseMeters.getY());
    SmartDashboard.putNumber("PPMecanumControllerCommand_rotationError", currentPose.getRotation().getRadians() - desiredState.holonomicRotation.getRadians());

    ChassisSpeeds targetChassisSpeeds = this.controller.calculate(currentPose, desiredState);
    MecanumDriveWheelSpeeds targetWheelSpeeds = this.kinematics.toWheelSpeeds(targetChassisSpeeds);

    targetWheelSpeeds.desaturate(this.maxWheelVelocityMetersPerSecond);

    this.outputWheelSpeeds.accept(targetWheelSpeeds);

    if(this.unpassedMarkers.size() > 0 && currentTime >= this.unpassedMarkers.get(0).timeSeconds) {
      PathPlannerTrajectory.EventMarker marker = this.unpassedMarkers.remove(0);

      if(this.eventMap.containsKey(marker.name)) {
        Command command = this.eventMap.get(marker.name);

        command.schedule();
      }
    }
  }

  @Override
  public void end(boolean interrupted) {
    this.timer.stop();
  }

  @Override
  public boolean isFinished() {
    return this.timer.hasElapsed(this.trajectory.getTotalTimeSeconds());
  }
}
