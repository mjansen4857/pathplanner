package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PPHolonomicDriveController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.HolonomicPathFollowerConfig;
import com.pathplanner.lib.util.PIDConstants;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class FollowPathHolonomic extends PathFollowingCommand {
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
    super(
        path,
        poseSupplier,
        speedsSupplier,
        outputRobotRelative,
        new PPHolonomicDriveController(
            translationConstants, rotationConstants, period, maxModuleSpeed, driveBaseRadius),
        requirements);
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
}
