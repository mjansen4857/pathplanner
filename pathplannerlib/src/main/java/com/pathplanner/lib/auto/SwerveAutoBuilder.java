package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.PPSwerveControllerCommand;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.SwerveDriveKinematics;
import edu.wpi.first.math.kinematics.SwerveModuleState;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.HashMap;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class SwerveAutoBuilder extends BaseAutoBuilder {
  private final Supplier<Pose2d> poseSupplier;
  private final SwerveDriveKinematics kinematics;
  private final PIDConstants translationConstants;
  private final PIDConstants rotationConstants;
  private final Consumer<SwerveModuleState[]> outputModuleStates;
  private final Subsystem[] driveRequirements;

  public SwerveAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      SwerveDriveKinematics kinematics,
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      Consumer<SwerveModuleState[]> outputModuleStates,
      HashMap<String, Command> eventMap,
      Subsystem... driveRequirements) {
    super(eventMap);

    this.poseSupplier = poseSupplier;
    this.kinematics = kinematics;
    this.translationConstants = translationConstants;
    this.rotationConstants = rotationConstants;
    this.outputModuleStates = outputModuleStates;
    this.driveRequirements = driveRequirements;
  }

  @Override
  protected CommandBase getPathFollowingCommand(PathPlannerTrajectory trajectory) {
    return new PPSwerveControllerCommand(
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
        outputModuleStates,
        driveRequirements);
  }
}
