package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.PPMecanumControllerCommand;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.MecanumDriveKinematics;
import edu.wpi.first.math.kinematics.MecanumDriveWheelSpeeds;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.HashMap;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class MecanumAutoBuilder extends BaseAutoBuilder {
  private final Supplier<Pose2d> poseSupplier;
  private final MecanumDriveKinematics kinematics;
  private final PIDConstants translationConstants;
  private final PIDConstants rotationConstants;
  private final double maxWheelVelocityMetersPerSecond;
  private final Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds;
  private final Subsystem[] driveRequirements;

  public MecanumAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      MecanumDriveKinematics kinematics,
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxWheelVelocityMetersPerSecond,
      Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds,
      HashMap<String, Command> eventMap,
      Subsystem... driveRequirements) {
    super(eventMap);

    this.poseSupplier = poseSupplier;
    this.kinematics = kinematics;
    this.translationConstants = translationConstants;
    this.rotationConstants = rotationConstants;
    this.maxWheelVelocityMetersPerSecond = maxWheelVelocityMetersPerSecond;
    this.outputWheelSpeeds = outputWheelSpeeds;
    this.driveRequirements = driveRequirements;
  }

  @Override
  protected CommandBase getPathFollowingCommand(PathPlannerTrajectory trajectory) {
    return new PPMecanumControllerCommand(
        trajectory,
        poseSupplier,
        kinematics,
        new PIDController(
            translationConstants.kP,
            translationConstants.kI,
            translationConstants.kD,
            translationConstants.period),
        new PIDController(
            translationConstants.kP,
            translationConstants.kI,
            translationConstants.kD,
            translationConstants.period),
        new PIDController(
            rotationConstants.kP,
            rotationConstants.kI,
            rotationConstants.kD,
            rotationConstants.period),
        maxWheelVelocityMetersPerSecond,
        outputWheelSpeeds,
        driveRequirements);
  }
}
