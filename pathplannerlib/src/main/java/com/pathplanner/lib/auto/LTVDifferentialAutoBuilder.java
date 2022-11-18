package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.PPLTVDifferentialDriveCommand;
import edu.wpi.first.math.controller.DifferentialDriveWheelVoltages;
import edu.wpi.first.math.controller.LTVDifferentialDriveController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.DifferentialDriveWheelSpeeds;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.HashMap;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class LTVDifferentialAutoBuilder extends BaseAutoBuilder {
  private final Supplier<Pose2d> poseSupplier;
  private final Supplier<DifferentialDriveWheelSpeeds> speedsSupplier;
  private final Consumer<DifferentialDriveWheelVoltages> outputVolts;
  private final LTVDifferentialDriveController controller;
  private final Subsystem[] driveRequirements;

  /**
   * Create an auto builder that will create command groups that will handle path following and
   * triggering events.
   *
   * <p>This auto builder will use PPLTVDifferentialDriveCommand to follow paths.
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param speedsSupplier A supplier that returns the current robot wheel speeds.
   * @param outputVolts A consumer that accepts the output of the controller.
   * @param controller The LTVDifferentialDriveController that will be used to follow the path.
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public LTVDifferentialAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Supplier<DifferentialDriveWheelSpeeds> speedsSupplier,
      Consumer<DifferentialDriveWheelVoltages> outputVolts,
      LTVDifferentialDriveController controller,
      HashMap<String, Command> eventMap,
      Subsystem... driveRequirements) {
    super(eventMap);

    this.poseSupplier = poseSupplier;
    this.speedsSupplier = speedsSupplier;
    this.outputVolts = outputVolts;
    this.controller = controller;
    this.driveRequirements = driveRequirements;
  }

  @Override
  public CommandBase followPath(PathPlannerTrajectory trajectory) {
    return new PPLTVDifferentialDriveCommand(
        trajectory, poseSupplier, speedsSupplier, outputVolts, controller, driveRequirements);
  }
}
