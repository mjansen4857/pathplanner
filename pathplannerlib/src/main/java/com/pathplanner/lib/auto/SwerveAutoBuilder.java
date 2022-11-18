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

  /**
   * Create an auto builder that will create command groups that will handle path following and
   * triggering events.
   *
   * <p>This auto builder will use PPSwerveControllerCommand to follow paths.
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param translationConstants PID Constants for the controller that will correct for translation
   *     error
   * @param rotationConstants PID Constants for the controller that will correct for rotation error
   * @param outputModuleStates A function that takes raw output module states from path following
   *     commands
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
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
