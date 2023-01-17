package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.PPMecanumControllerCommand;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.MecanumDriveKinematics;
import edu.wpi.first.math.kinematics.MecanumDriveWheelSpeeds;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.Map;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class MecanumAutoBuilder extends BaseAutoBuilder {
  private final MecanumDriveKinematics kinematics;
  private final PIDConstants translationConstants;
  private final PIDConstants rotationConstants;
  private final double maxWheelVelocityMetersPerSecond;
  private final Consumer<MecanumDriveWheelSpeeds> outputWheelSpeeds;
  private final Consumer<ChassisSpeeds> outputChassisSpeeds;
  private final Subsystem[] driveRequirements;

  private final boolean useKinematics;

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
   * @param translationConstants PID Constants for the controller that will correct for translation
   *     error
   * @param rotationConstants PID Constants for the controller that will correct for rotation error
   * @param outputChassisSpeeds A consumer for a ChassisSpeeds object containing the output speeds.
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public MecanumAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      Consumer<ChassisSpeeds> outputChassisSpeeds,
      Map<String, Command> eventMap,
      Subsystem... driveRequirements) {
    this(
        poseSupplier,
        resetPose,
        translationConstants,
        rotationConstants,
        outputChassisSpeeds,
        eventMap,
        true,
        driveRequirements);
  }

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
   * @param outputWheelSpeeds A consumer for a MecanumDriveWheelSpeeds object containing the output
   *     wheel speeds.
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
      Map<String, Command> eventMap,
      Subsystem... driveRequirements) {
    this(
        poseSupplier,
        resetPose,
        kinematics,
        translationConstants,
        rotationConstants,
        maxWheelVelocityMetersPerSecond,
        outputWheelSpeeds,
        eventMap,
        true,
        driveRequirements);
  }

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
   * @param translationConstants PID Constants for the controller that will correct for translation
   *     error
   * @param rotationConstants PID Constants for the controller that will correct for rotation error
   * @param outputChassisSpeeds A consumer for a ChassisSpeeds object containing the output speeds.
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param useAllianceColor Should the path states be automatically transformed based on alliance
   *     color? In order for this to work properly, you MUST create your path on the blue side of
   *     the field.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public MecanumAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      Consumer<ChassisSpeeds> outputChassisSpeeds,
      Map<String, Command> eventMap,
      boolean useAllianceColor,
      Subsystem... driveRequirements) {
    super(poseSupplier, resetPose, eventMap, DrivetrainType.HOLONOMIC, useAllianceColor);

    this.kinematics = null;
    this.translationConstants = translationConstants;
    this.rotationConstants = rotationConstants;
    this.maxWheelVelocityMetersPerSecond = 0;
    this.outputWheelSpeeds = null;
    this.outputChassisSpeeds = outputChassisSpeeds;
    this.driveRequirements = driveRequirements;

    this.useKinematics = false;
  }

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
   * @param outputWheelSpeeds A consumer for a MecanumDriveWheelSpeeds object containing the output
   *     wheel speeds.
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param useAllianceColor Should the path states be automatically transformed based on alliance
   *     color? In order for this to work properly, you MUST create your path on the blue side of
   *     the field.
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
      Map<String, Command> eventMap,
      boolean useAllianceColor,
      Subsystem... driveRequirements) {
    super(poseSupplier, resetPose, eventMap, DrivetrainType.HOLONOMIC, useAllianceColor);

    this.kinematics = kinematics;
    this.translationConstants = translationConstants;
    this.rotationConstants = rotationConstants;
    this.maxWheelVelocityMetersPerSecond = maxWheelVelocityMetersPerSecond;
    this.outputWheelSpeeds = outputWheelSpeeds;
    this.outputChassisSpeeds = null;
    this.driveRequirements = driveRequirements;

    this.useKinematics = true;
  }

  @Override
  public CommandBase followPath(PathPlannerTrajectory trajectory) {
    if (useKinematics) {
      return new PPMecanumControllerCommand(
          trajectory,
          poseSupplier,
          kinematics,
          pidControllerFromConstants(translationConstants),
          pidControllerFromConstants(translationConstants),
          pidControllerFromConstants(rotationConstants),
          maxWheelVelocityMetersPerSecond,
          outputWheelSpeeds,
          useAllianceColor,
          driveRequirements);
    } else {
      return new PPMecanumControllerCommand(
          trajectory,
          poseSupplier,
          pidControllerFromConstants(translationConstants),
          pidControllerFromConstants(translationConstants),
          pidControllerFromConstants(rotationConstants),
          outputChassisSpeeds,
          useAllianceColor,
          driveRequirements);
    }
  }
}
