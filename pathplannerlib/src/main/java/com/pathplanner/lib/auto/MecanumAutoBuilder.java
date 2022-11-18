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
  private final MecanumDriveKinematics kinematics;
  private final PIDConstants translationConstants;
  private final PIDConstants rotationConstants;
  private final double maxWheelVelocityMetersPerSecond;
  private final Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds;
  private final Subsystem[] driveRequirements;

  /**
   * Create an auto builder that will create command groups that will handle path following and
   * triggering events.
   *
   * <p>This auto builder will use PPMecanumControllerCommand to follow paths.
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
   *     be called once at the beginning of an auto.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param translationConstants PID Constants for the controller that will correct for translation
   *     error
   * @param rotationConstants PID Constants for the controller that will correct for rotation error
   * @param maxWheelVelocityMetersPerSecond The maximum velocity of a drivetrain wheel.
   * @param outputWheelSpeeds A MecanumDriveWheelSpeeds object containing the output wheel speeds.
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public MecanumAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      MecanumDriveKinematics kinematics,
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxWheelVelocityMetersPerSecond,
      Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds,
      HashMap<String, Command> eventMap,
      Subsystem... driveRequirements) {
    super(poseSupplier, resetPose, eventMap, DrivetrainType.HOLONOMIC);

    this.kinematics = kinematics;
    this.translationConstants = translationConstants;
    this.rotationConstants = rotationConstants;
    this.maxWheelVelocityMetersPerSecond = maxWheelVelocityMetersPerSecond;
    this.outputWheelSpeeds = outputWheelSpeeds;
    this.driveRequirements = driveRequirements;
  }

  @Override
  public CommandBase followPath(PathPlannerTrajectory trajectory) {
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
