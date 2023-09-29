package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PPLTVController;
import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.math.Vector;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.numbers.N2;
import edu.wpi.first.math.numbers.N3;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class FollowPathLTV extends PathFollowingCommand {
  public FollowPathLTV(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      double dt,
      Subsystem... requirements) {
    super(path, poseSupplier, speedsSupplier, output, new PPLTVController(dt), requirements);
  }

  public FollowPathLTV(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      Vector<N3> qelems,
      Vector<N2> relems,
      double dt,
      Subsystem... requirements) {
    super(
        path,
        poseSupplier,
        speedsSupplier,
        output,
        new PPLTVController(qelems, relems, dt),
        requirements);
  }
}
