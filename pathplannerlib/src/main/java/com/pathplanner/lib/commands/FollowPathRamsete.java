package com.pathplanner.lib.commands;

import com.pathplanner.lib.controllers.PPRamseteController;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.ReplanningConfig;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Follow a path using a PPRamseteController */
public class FollowPathRamsete extends FollowPathCommand {
  /**
   * Construct a path following command that will use a Ramsete path following controller for
   * differential drive trains
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param output Function that will apply the robot-relative output speeds of this command
   * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
   *     aggressive like a proportional term.
   * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
   *     more damping in response.
   * @param replanningConfig Path replanning configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
   *     maintain a global blue alliance origin.
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
  public FollowPathRamsete(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      double b,
      double zeta,
      ReplanningConfig replanningConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    super(
        path,
        poseSupplier,
        speedsSupplier,
        output,
        new PPRamseteController(b, zeta),
        replanningConfig,
        shouldFlipPath,
        requirements);

    if (path.isChoreoPath()) {
      throw new IllegalArgumentException(
          "Paths loaded from Choreo cannot be used with differential drivetrains");
    }
  }

  /**
   * Construct a path following command that will use a Ramsete path following controller for
   * differential drive trains
   *
   * @param path The path to follow
   * @param poseSupplier Function that supplies the current field-relative pose of the robot
   * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
   * @param output Function that will apply the robot-relative output speeds of this command
   * @param replanningConfig Path replanning configuration
   * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
   *     maintain a global blue alliance origin.
   * @param requirements Subsystems required by this command, usually just the drive subsystem
   */
  public FollowPathRamsete(
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      Supplier<ChassisSpeeds> speedsSupplier,
      Consumer<ChassisSpeeds> output,
      ReplanningConfig replanningConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... requirements) {
    super(
        path,
        poseSupplier,
        speedsSupplier,
        output,
        new PPRamseteController(),
        replanningConfig,
        shouldFlipPath,
        requirements);

    if (path.isChoreoPath()) {
      throw new IllegalArgumentException(
          "Paths loaded from Choreo cannot be used with differential drivetrains");
    }
  }
}
