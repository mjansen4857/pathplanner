package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.PPRamseteCommand;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.controller.RamseteController;
import edu.wpi.first.math.controller.SimpleMotorFeedforward;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.DifferentialDriveKinematics;
import edu.wpi.first.math.kinematics.DifferentialDriveWheelSpeeds;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.HashMap;
import java.util.function.BiConsumer;
import java.util.function.Supplier;

public class RamseteAutoBuilder extends BaseAutoBuilder {
  private final Supplier<Pose2d> poseSupplier;
  private final RamseteController controller;
  private final SimpleMotorFeedforward feedforward;
  private final DifferentialDriveKinematics kinematics;
  private final Supplier<DifferentialDriveWheelSpeeds> speedsSupplier;
  private final PIDConstants driveConstants;
  private final BiConsumer<Double, Double> outputVolts;
  private final Subsystem[] driveRequirements;

  public RamseteAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      RamseteController controller,
      SimpleMotorFeedforward feedforward,
      DifferentialDriveKinematics kinematics,
      Supplier<DifferentialDriveWheelSpeeds> speedsSupplier,
      PIDConstants driveConstants,
      BiConsumer<Double, Double> outputVolts,
      HashMap<String, Command> eventMap,
      Subsystem... driveRequirements) {
    super(eventMap);

    this.poseSupplier = poseSupplier;
    this.controller = controller;
    this.feedforward = feedforward;
    this.kinematics = kinematics;
    this.speedsSupplier = speedsSupplier;
    this.driveConstants = driveConstants;
    this.outputVolts = outputVolts;
    this.driveRequirements = driveRequirements;
  }

  @Override
  protected CommandBase getPathFollowingCommand(PathPlannerTrajectory trajectory) {
    return new PPRamseteCommand(
        trajectory,
        poseSupplier,
        controller,
        feedforward,
        kinematics,
        speedsSupplier,
        new PIDController(
            driveConstants.kP, driveConstants.kI, driveConstants.kD, driveConstants.period),
        new PIDController(
            driveConstants.kP, driveConstants.kI, driveConstants.kD, driveConstants.period),
        outputVolts,
        driveRequirements);
  }
}
