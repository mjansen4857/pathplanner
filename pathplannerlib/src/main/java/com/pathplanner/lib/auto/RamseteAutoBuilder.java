package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.PPRamseteCommand;
import edu.wpi.first.math.controller.RamseteController;
import edu.wpi.first.math.controller.SimpleMotorFeedforward;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.DifferentialDriveKinematics;
import edu.wpi.first.math.kinematics.DifferentialDriveWheelSpeeds;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.Map;
import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class RamseteAutoBuilder extends BaseAutoBuilder {
  private final RamseteController controller;
  private final DifferentialDriveKinematics kinematics;
  private final SimpleMotorFeedforward feedforward;
  private final Supplier<DifferentialDriveWheelSpeeds> speedsSupplier;
  private final PIDConstants driveConstants;
  private final BiConsumer<Double, Double> output;
  private final Subsystem[] driveRequirements;

  private final boolean usePID;

  /**
   * Create an auto builder that will create command groups that will handle path following and
   * triggering events.
   *
   * <p>This auto builder will use PPRamseteCommand to follow paths.
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
   *     be called once at the beginning of an auto.
   * @param controller The RAMSETE controller used to follow the trajectory.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param feedforward The feedforward to use for the drive.
   * @param speedsSupplier A function that supplies the speeds of the left and right sides of the
   *     robot drive.
   * @param driveConstants PIDConstants for each side of the drive train
   * @param outputVolts Output consumer that accepts left and right voltages
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public RamseteAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      RamseteController controller,
      DifferentialDriveKinematics kinematics,
      SimpleMotorFeedforward feedforward,
      Supplier<DifferentialDriveWheelSpeeds> speedsSupplier,
      PIDConstants driveConstants,
      BiConsumer<Double, Double> outputVolts,
      Map<String, Command> eventMap,
      Subsystem... driveRequirements) {
    this(
        poseSupplier,
        resetPose,
        controller,
        kinematics,
        feedforward,
        speedsSupplier,
        driveConstants,
        outputVolts,
        eventMap,
        true,
        driveRequirements);
  }

  /**
   * Create an auto builder that will create command groups that will handle path following and
   * triggering events.
   *
   * <p>This auto builder will use PPRamseteCommand to follow paths.
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
   *     be called once at the beginning of an auto.
   * @param controller The RAMSETE controller used to follow the trajectory.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param outputMetersPerSecond Output consumer that accepts left and right speeds
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public RamseteAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      RamseteController controller,
      DifferentialDriveKinematics kinematics,
      BiConsumer<Double, Double> outputMetersPerSecond,
      Map<String, Command> eventMap,
      Subsystem... driveRequirements) {
    this(
        poseSupplier,
        resetPose,
        controller,
        kinematics,
        outputMetersPerSecond,
        eventMap,
        true,
        driveRequirements);
  }

  /**
   * Create an auto builder that will create command groups that will handle path following and
   * triggering events.
   *
   * <p>This auto builder will use PPRamseteCommand to follow paths.
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
   *     be called once at the beginning of an auto.
   * @param controller The RAMSETE controller used to follow the trajectory.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param feedforward The feedforward to use for the drive.
   * @param speedsSupplier A function that supplies the speeds of the left and right sides of the
   *     robot drive.
   * @param driveConstants PIDConstants for each side of the drive train
   * @param outputVolts Output consumer that accepts left and right voltages
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param useAllianceColor Should the path states be automatically transformed based on alliance
   *     color? In order for this to work properly, you MUST create your path on the blue side of
   *     the field.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public RamseteAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      RamseteController controller,
      DifferentialDriveKinematics kinematics,
      SimpleMotorFeedforward feedforward,
      Supplier<DifferentialDriveWheelSpeeds> speedsSupplier,
      PIDConstants driveConstants,
      BiConsumer<Double, Double> outputVolts,
      Map<String, Command> eventMap,
      boolean useAllianceColor,
      Subsystem... driveRequirements) {
    super(poseSupplier, resetPose, eventMap, DrivetrainType.STANDARD, useAllianceColor);

    this.controller = controller;
    this.kinematics = kinematics;
    this.feedforward = feedforward;
    this.speedsSupplier = speedsSupplier;
    this.driveConstants = driveConstants;
    this.output = outputVolts;
    this.driveRequirements = driveRequirements;

    this.usePID = true;
  }

  /**
   * Create an auto builder that will create command groups that will handle path following and
   * triggering events.
   *
   * <p>This auto builder will use PPRamseteCommand to follow paths.
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
   *     be called once at the beginning of an auto.
   * @param controller The RAMSETE controller used to follow the trajectory.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param outputMetersPerSecond Output consumer that accepts left and right speeds
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param useAllianceColor Should the path states be automatically transformed based on alliance
   *     color? In order for this to work properly, you MUST create your path on the blue side of
   *     the field.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public RamseteAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      RamseteController controller,
      DifferentialDriveKinematics kinematics,
      BiConsumer<Double, Double> outputMetersPerSecond,
      Map<String, Command> eventMap,
      boolean useAllianceColor,
      Subsystem... driveRequirements) {
    super(poseSupplier, resetPose, eventMap, DrivetrainType.STANDARD, useAllianceColor);

    this.controller = controller;
    this.kinematics = kinematics;
    this.feedforward = null;
    this.speedsSupplier = null;
    this.driveConstants = null;
    this.output = outputMetersPerSecond;
    this.driveRequirements = driveRequirements;

    this.usePID = false;
  }

  @Override
  public CommandBase followPath(PathPlannerTrajectory trajectory) {
    if (usePID) {
      return new PPRamseteCommand(
          trajectory,
          poseSupplier,
          controller,
          feedforward,
          kinematics,
          speedsSupplier,
          pidControllerFromConstants(driveConstants),
          pidControllerFromConstants(driveConstants),
          output,
          useAllianceColor,
          driveRequirements);
    } else {
      return new PPRamseteCommand(
          trajectory,
          poseSupplier,
          controller,
          kinematics,
          output,
          useAllianceColor,
          driveRequirements);
    }
  }
}
