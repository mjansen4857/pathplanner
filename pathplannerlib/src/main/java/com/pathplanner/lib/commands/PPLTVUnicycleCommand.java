package com.pathplanner.lib.commands;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.server.PathPlannerServer;
import edu.wpi.first.math.controller.LTVUnicycleController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj.smartdashboard.Field2d;
import edu.wpi.first.wpilibj.smartdashboard.SmartDashboard;
import edu.wpi.first.wpilibj2.command.*;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PPLTVUnicycleCommand extends CommandBase {
  private final Timer timer = new Timer();
  private final PathPlannerTrajectory trajectory;
  private final Supplier<Pose2d> poseSupplier;
  private final Consumer<ChassisSpeeds> output;
  private final LTVUnicycleController controller;

  private final Field2d field = new Field2d();

  /**
   * Creates a new PPLTVUnicycleCommand. This command will follow the given trajectory using an
   * LTVUnicycleController.
   *
   * @param trajectory The trajectory to follow.
   * @param poseSupplier A supplier that returns the current robot pose.
   * @param output A consumer that accepts the output of the controller.
   * @param controller The LTVUnicycleController that will be used to follow the path.
   * @param requirements The subsystems required by this command.
   */
  public PPLTVUnicycleCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      Consumer<ChassisSpeeds> output,
      LTVUnicycleController controller,
      Subsystem... requirements) {
    this.trajectory = trajectory;
    this.poseSupplier = poseSupplier;
    this.output = output;
    this.controller = controller;

    addRequirements(requirements);
  }

  @Override
  public void initialize() {
    SmartDashboard.putData("PPLTVUnicycleCommand_field", this.field);
    this.field.getObject("traj").setTrajectory(this.trajectory);

    PathPlannerServer.sendActivePath(this.trajectory.getStates());

    this.timer.reset();
    this.timer.start();
  }

  @Override
  public void execute() {
    double currentTime = this.timer.get();

    Pose2d currentPose = this.poseSupplier.get();
    PathPlannerTrajectory.PathPlannerState desiredState =
        (PathPlannerTrajectory.PathPlannerState) this.trajectory.sample(currentTime);
    this.field.setRobotPose(currentPose);
    PathPlannerServer.sendPathFollowingData(desiredState.poseMeters, currentPose);

    SmartDashboard.putNumber(
        "PPLTVUnicycleCommand_xError", currentPose.getX() - desiredState.poseMeters.getX());
    SmartDashboard.putNumber(
        "PPLTVUnicycleCommand_yError", currentPose.getY() - desiredState.poseMeters.getY());
    SmartDashboard.putNumber(
        "PPLTVUnicycleCommand_rotationError",
        currentPose.getRotation().getRadians()
            - desiredState.poseMeters.getRotation().getRadians());

    this.output.accept(this.controller.calculate(currentPose, desiredState));
  }

  @Override
  public void end(boolean interrupted) {
    this.timer.stop();

    if (interrupted) {
      this.output.accept(new ChassisSpeeds(0, 0, 0));
    }
  }

  @Override
  public boolean isFinished() {
    return this.timer.hasElapsed(this.trajectory.getTotalTimeSeconds());
  }
}
