package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PPLTVController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.ReplanningConfig;
import edu.wpi.first.math.Vector;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.numbers.N2;
import edu.wpi.first.math.numbers.N3;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Follow a path using a PPLTVController */
public class FollowPathLTV extends FollowPathCommand {
  /**
   * Create a path following command that will use an LTV unicycle controller for differential drive
   * trains
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param output Function that will apply the robot-relative output speeds of this command
   * @param dt The amount of time between each robot control loop, default is 0.02s
   * @param replanningConfig Path replanning configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
   *     maintain a global blue alliance origin.
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
  public FollowPathLTV(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      double dt,
      ReplanningConfig replanningConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    super(
        path,
        poseSupplier,
        speedsSupplier,
        output,
        new PPLTVController(dt),
        replanningConfig,
        shouldFlipPath,
        requirements);

    if (path.isChoreoPath()) {
      throw new IllegalArgumentException(
          "Paths loaded from Choreo cannot be used with differential drivetrains");
    }
  }

  /**
   * Create a path following command that will use an LTV unicycle controller for differential drive
   * trains
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param output Function that will apply the robot-relative output speeds of this command
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt The amount of time between each robot control loop, default is 0.02s
   * @param replanningConfig Path replanning configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
   *     maintain a global blue alliance origin.
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
  public FollowPathLTV(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      Vector<N3> qelems,
      Vector<N2> relems,
      double dt,
      ReplanningConfig replanningConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    super(
        path,
        poseSupplier,
        speedsSupplier,
        output,
        new PPLTVController(qelems, relems, dt),
        replanningConfig,
        shouldFlipPath,
        requirements);

    if (path.isChoreoPath()) {
      throw new IllegalArgumentException(
          "Paths loaded from Choreo cannot be used with differential drivetrains");
    }
  }
}
