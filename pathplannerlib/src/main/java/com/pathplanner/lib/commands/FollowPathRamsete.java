package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PPRamseteController;
import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class FollowPathRamsete extends PathFollowingCommand {
  public FollowPathRamsete(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      double b,
      double zeta,
      Subsystem... requirements) {
    super(
        path, poseSupplier, speedsSupplier, output, new PPRamseteController(b, zeta), requirements);
  }

  public FollowPathRamsete(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      Subsystem... requirements) {
    super(path, poseSupplier, speedsSupplier, output, new PPRamseteController(), requirements);
  }
}
