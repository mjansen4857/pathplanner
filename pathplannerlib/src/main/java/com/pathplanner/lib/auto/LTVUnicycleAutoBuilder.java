package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.PPLTVUnicycleCommand;
import edu.wpi.first.math.controller.LTVUnicycleController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.HashMap;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class LTVUnicycleAutoBuilder extends BaseAutoBuilder {
  private final Consumer<ChassisSpeeds> outputChassisSpeeds;
  private final LTVUnicycleController controller;
  private final Subsystem[] driveRequirements;

  /**
   * Create an auto builder that will create command groups that will handle path following and
   * triggering events.
   *
   * <p>This auto builder will use PPLTVUnicycleCommand to follow paths.
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
   *     be called once at the beginning of an auto.
   * @param outputChassisSpeeds A consumer that accepts the output of the controller.
   * @param controller The LTVUnicycleController that will be used to follow the path.
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker.
   * @param driveRequirements The subsystems that the path following commands should require.
   *     Usually just a Drive subsystem.
   */
  public LTVUnicycleAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      Consumer<ChassisSpeeds> outputChassisSpeeds,
      LTVUnicycleController controller,
      HashMap<String, Command> eventMap,
      Subsystem... driveRequirements) {
    super(poseSupplier, resetPose, eventMap, DrivetrainType.STANDARD);

    this.outputChassisSpeeds = outputChassisSpeeds;
    this.controller = controller;
    this.driveRequirements = driveRequirements;
  }

  @Override
  public CommandBase followPath(PathPlannerTrajectory trajectory) {
    return new PPLTVUnicycleCommand(
        trajectory, poseSupplier, outputChassisSpeeds, controller, driveRequirements);
  }
}
