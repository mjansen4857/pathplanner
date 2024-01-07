package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.HolonomicPathFollowerConfig;
import com.pathplanner.lib.util.PIDConstants;
import com.pathplanner.lib.util.ReplanningConfig;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Follow a path using a PPHolonomicDriveController */
public class FollowPathHolonomic extends FollowPathCommand {
  /**
   * Construct a path following command that will use a holonomic drive controller for holonomic
   * drive trains
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param outputRobotRelative Function that will apply the robot-relative output speeds of this
   *     command
   * @param translationConstants PID constants for the translation PID controllers
   * @param rotationConstants PID constants for the rotation controller
   * @param maxModuleSpeed The max speed of a drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
   *     distance from the center of the robot to the furthest module. For mecanum, this is the
   *     drive base width / 2
   * @param period Period of the control loop in seconds, default is 0.02s
   * @param replanningConfig Path replanning configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
   *     maintain a global blue alliance origin.
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
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
      ReplanningConfig replanningConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    super(
        path,
        poseSupplier,
        speedsSupplier,
        outputRobotRelative,
        new PPHolonomicDriveController(
            translationConstants, rotationConstants, period, maxModuleSpeed, driveBaseRadius),
        replanningConfig,
        shouldFlipPath,
        requirements);
  }

  /**
   * Construct a path following command that will use a holonomic drive controller for holonomic
   * drive trains
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param outputRobotRelative Function that will apply the robot-relative output speeds of this
   *     command
   * @param translationConstants PID constants for the translation PID controllers
   * @param rotationConstants PID constants for the rotation controller
   * @param maxModuleSpeed The max speed of a drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
   *     distance from the center of the robot to the furthest module. For mecanum, this is the
   *     drive base width / 2
   * @param replanningConfig Path replanning configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
   *     maintain a global blue alliance origin.
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
  public FollowPathHolonomic(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxModuleSpeed,
      double driveBaseRadius,
      ReplanningConfig replanningConfig,
      BooleanSupplier shouldFlipPath,
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
        replanningConfig,
        shouldFlipPath,
        requirements);
  }

  /**
   * Construct a path following command that will use a holonomic drive controller for holonomic
   * drive trains
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param outputRobotRelative Function that will apply the robot-relative output speeds of this
   *     command
   * @param config Holonomic path follower configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
   *     maintain a global blue alliance origin.
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
  public FollowPathHolonomic(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> outputRobotRelative,
      HolonomicPathFollowerConfig config,
      BooleanSupplier shouldFlipPath,
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
        config.replanningConfig,
        shouldFlipPath,
        requirements);
  }
}
