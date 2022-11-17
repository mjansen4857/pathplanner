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
  private final Supplier<Pose2d> poseSupplier;
  private final Consumer<ChassisSpeeds> outputChassisSpeeds;
  private final LTVUnicycleController controller;
  private final Subsystem[] driveRequirements;

  public LTVUnicycleAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<ChassisSpeeds> outputChassisSpeeds,
      LTVUnicycleController controller,
      HashMap<String, Command> eventMap,
      Subsystem... driveRequirements) {
    super(eventMap);

    this.poseSupplier = poseSupplier;
    this.outputChassisSpeeds = outputChassisSpeeds;
    this.controller = controller;
    this.driveRequirements = driveRequirements;
  }

  @Override
  protected CommandBase getPathFollowingCommand(PathPlannerTrajectory trajectory) {
    return new PPLTVUnicycleCommand(
        trajectory, poseSupplier, outputChassisSpeeds, controller, driveRequirements);
  }
}
