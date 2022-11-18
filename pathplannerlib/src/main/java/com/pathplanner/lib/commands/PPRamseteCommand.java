package com.pathplanner.lib.commands;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.server.PathPlannerServer;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.controller.RamseteController;
import edu.wpi.first.math.controller.SimpleMotorFeedforward;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.DifferentialDriveKinematics;
import edu.wpi.first.math.kinematics.DifferentialDriveWheelSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj.smartdashboard.Field2d;
import edu.wpi.first.wpilibj.smartdashboard.SmartDashboard;
import edu.wpi.first.wpilibj2.command.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.function.BiConsumer;
import java.util.function.Supplier;

/** Custom PathPlanner version of RamseteCommand */
public class PPRamseteCommand extends CommandBase {
  private final Timer timer = new Timer();
  private final boolean usePID;
  private final PathPlannerTrajectory trajectory;
  private final Supplier<Pose2d> poseSupplier;
  private final RamseteController controller;
  private final SimpleMotorFeedforward feedforward;
  private final DifferentialDriveKinematics kinematics;
  private final Supplier<DifferentialDriveWheelSpeeds> speedsSupplier;
  private final PIDController leftController;
  private final PIDController rightController;
  private final BiConsumer<Double, Double> output;
  private final HashMap<String, Command> eventMap;
  private final Field2d field = new Field2d();

  private DifferentialDriveWheelSpeeds prevSpeeds;
  private double prevTime;
  private ArrayList<PathPlannerTrajectory.EventMarker> unpassedMarkers;

  /**
   * Constructs a new PPRamseteCommand that, when executed, will follow the provided trajectory. PID
   * control and feedforward are handled internally, and outputs are scaled -12 to 12 representing
   * units of volts.
   *
   * <p>Note: The controller will *not* set the outputVolts to zero upon completion of the path -
   * this is left to the user, since it is not appropriate for paths with nonstationary endstates.
   *
   * <p>NOTE: Do not use this command with an event map inside of an autonomous command group unless
   * you are sure it will work fine. If an event marker triggers a command for a subsystem required
   * by the command group, the command group will be interrupted. Instead, use RamseteAutoBuilder to
   * create a path following command that will trigger events without interrupting the main command
   * group.
   *
   * @param trajectory The trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param controller The RAMSETE controller used to follow the trajectory.
   * @param feedforward The feedforward to use for the drive.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param speedsSupplier A function that supplies the speeds of the left and right sides of the
   *     robot drive.
   * @param leftController The PIDController for the left side of the robot drive.
   * @param rightController The PIDController for the right side of the robot drive.
   * @param outputVolts A function that consumes the computed left and right outputs (in volts) for
   *     the robot drive.
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker. This SHOULD NOT contain any commands requiring the same subsystems as this command,
   *     or it will be interrupted
   * @param requirements The subsystems to require.
   */
  public PPRamseteCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      RamseteController controller,
      SimpleMotorFeedforward feedforward,
      DifferentialDriveKinematics kinematics,
      Supplier<DifferentialDriveWheelSpeeds> speedsSupplier,
      PIDController leftController,
      PIDController rightController,
      BiConsumer<Double, Double> outputVolts,
      HashMap<String, Command> eventMap,
      Subsystem... requirements) {
    this.trajectory = trajectory;
    this.poseSupplier = poseSupplier;
    this.controller = controller;
    this.feedforward = feedforward;
    this.kinematics = kinematics;
    this.speedsSupplier = speedsSupplier;
    this.leftController = leftController;
    this.rightController = rightController;
    this.output = outputVolts;
    this.eventMap = eventMap;

    this.usePID = true;

    addRequirements(requirements);
  }

  /**
   * Constructs a new PPRamseteCommand that, when executed, will follow the provided trajectory.
   * Performs no PID control and calculates no feedforwards; outputs are the raw wheel speeds from
   * the RAMSETE controller, and will need to be converted into a usable form by the user.
   *
   * <p>NOTE: Do not use this command with an event map inside of an autonomous command group unless
   * you are sure it will work fine. If an event marker triggers a command for a subsystem required
   * by the command group, the command group will be interrupted. Instead, use RamseteAutoBuilder to
   * create a path following command that will trigger events without interrupting the main command
   * group.
   *
   * @param trajectory The trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param controller The RAMSETE follower used to follow the trajectory.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param outputMetersPerSecond A function that consumes the computed left and right wheel speeds.
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker. This SHOULD NOT contain any commands requiring the same subsystems as this command,
   *     or it will be interrupted
   * @param requirements The subsystems to require.
   */
  public PPRamseteCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      RamseteController controller,
      DifferentialDriveKinematics kinematics,
      BiConsumer<Double, Double> outputMetersPerSecond,
      HashMap<String, Command> eventMap,
      Subsystem... requirements) {
    this.trajectory = trajectory;
    this.poseSupplier = poseSupplier;
    this.controller = controller;
    this.kinematics = kinematics;
    this.output = outputMetersPerSecond;
    this.eventMap = eventMap;

    this.feedforward = null;
    this.speedsSupplier = null;
    this.leftController = null;
    this.rightController = null;

    this.usePID = false;

    addRequirements(requirements);
  }

  /**
   * Constructs a new PPRamseteCommand that, when executed, will follow the provided trajectory. PID
   * control and feedforward are handled internally, and outputs are scaled -12 to 12 representing
   * units of volts.
   *
   * <p>Note: The controller will *not* set the outputVolts to zero upon completion of the path -
   * this is left to the user, since it is not appropriate for paths with nonstationary endstates.
   *
   * @param trajectory The trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param controller The RAMSETE controller used to follow the trajectory.
   * @param feedforward The feedforward to use for the drive.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param speedsSupplier A function that supplies the speeds of the left and right sides of the
   *     robot drive.
   * @param leftController The PIDController for the left side of the robot drive.
   * @param rightController The PIDController for the right side of the robot drive.
   * @param outputVolts A function that consumes the computed left and right outputs (in volts) for
   *     the robot drive.
   * @param requirements The subsystems to require.
   */
  public PPRamseteCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      RamseteController controller,
      SimpleMotorFeedforward feedforward,
      DifferentialDriveKinematics kinematics,
      Supplier<DifferentialDriveWheelSpeeds> speedsSupplier,
      PIDController leftController,
      PIDController rightController,
      BiConsumer<Double, Double> outputVolts,
      Subsystem... requirements) {
    this(
        trajectory,
        poseSupplier,
        controller,
        feedforward,
        kinematics,
        speedsSupplier,
        leftController,
        rightController,
        outputVolts,
        new HashMap<>(),
        requirements);
  }

  /**
   * Constructs a new PPRamseteCommand that, when executed, will follow the provided trajectory.
   * Performs no PID control and calculates no feedforwards; outputs are the raw wheel speeds from
   * the RAMSETE controller, and will need to be converted into a usable form by the user.
   *
   * @param trajectory The trajectory to follow.
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param controller The RAMSETE follower used to follow the trajectory.
   * @param kinematics The kinematics for the robot drivetrain.
   * @param outputMetersPerSecond A function that consumes the computed left and right wheel speeds.
   * @param requirements The subsystems to require.
   */
  public PPRamseteCommand(
      PathPlannerTrajectory trajectory,
      Supplier<Pose2d> poseSupplier,
      RamseteController controller,
      DifferentialDriveKinematics kinematics,
      BiConsumer<Double, Double> outputMetersPerSecond,
      Subsystem... requirements) {
    this(
        trajectory,
        poseSupplier,
        controller,
        kinematics,
        outputMetersPerSecond,
        new HashMap<>(),
        requirements);
  }

  @Override
  public void initialize() {
    if (this.trajectory.getMarkers().size() > 0 && this.eventMap.size() > 0) {
      try {
        CommandGroupBase.requireUngrouped(this);
      } catch (IllegalArgumentException e) {
        throw new RuntimeException(
                "Path following commands cannot be added to command groups if using "
                        + "event markers, as the events could interrupt the command group. Instead, please use "
                        + "RamseteAutoBuilder to create a command group safe path following command.");
      }
    }

    this.unpassedMarkers = new ArrayList<>();
    this.unpassedMarkers.addAll(this.trajectory.getMarkers());
    this.prevTime = -1;

    SmartDashboard.putData("PPRamseteCommand_field", this.field);
    this.field.getObject("traj").setTrajectory(this.trajectory);

    PathPlannerTrajectory.PathPlannerState initialState = this.trajectory.getInitialState();
    this.prevSpeeds =
        this.kinematics.toWheelSpeeds(
            new ChassisSpeeds(
                initialState.velocityMetersPerSecond,
                0,
                initialState.curvatureRadPerMeter * initialState.velocityMetersPerSecond));

    this.timer.reset();
    this.timer.start();

    if (this.usePID) {
      this.leftController.reset();
      this.rightController.reset();
    }

    PathPlannerServer.sendActivePath(this.trajectory.getStates());
  }

  @Override
  public void execute() {
    double currentTime = this.timer.get();
    double dt = currentTime - this.prevTime;

    if (this.prevTime < 0) {
      this.prevTime = currentTime;
      return;
    }

    Pose2d currentPose = this.poseSupplier.get();
    PathPlannerTrajectory.PathPlannerState desiredState =
        (PathPlannerTrajectory.PathPlannerState) this.trajectory.sample(currentTime);
    this.field.setRobotPose(currentPose);
    PathPlannerServer.sendPathFollowingData(desiredState.poseMeters, currentPose);

    SmartDashboard.putNumber(
        "PPRamseteCommand_xError", currentPose.getX() - desiredState.poseMeters.getX());
    SmartDashboard.putNumber(
        "PPRamseteCommand_yError", currentPose.getY() - desiredState.poseMeters.getY());
    SmartDashboard.putNumber(
        "PPRamseteCommand_rotationError",
        currentPose.getRotation().getRadians()
            - desiredState.poseMeters.getRotation().getRadians());

    DifferentialDriveWheelSpeeds targetWheelSpeeds =
        this.kinematics.toWheelSpeeds(this.controller.calculate(currentPose, desiredState));

    double leftSpeedSetpoint = targetWheelSpeeds.leftMetersPerSecond;
    double rightSpeedSetpoint = targetWheelSpeeds.rightMetersPerSecond;

    double leftOutput;
    double rightOutput;

    if (this.usePID) {
      double leftFeedforward =
          this.feedforward.calculate(
              leftSpeedSetpoint, (leftSpeedSetpoint - this.prevSpeeds.leftMetersPerSecond) / dt);
      double rightFeedforward =
          this.feedforward.calculate(
              rightSpeedSetpoint, (rightSpeedSetpoint - this.prevSpeeds.rightMetersPerSecond) / dt);

      leftOutput =
          leftFeedforward
              + this.leftController.calculate(
                  this.speedsSupplier.get().leftMetersPerSecond, leftSpeedSetpoint);
      rightOutput =
          rightFeedforward
              + this.rightController.calculate(
                  this.speedsSupplier.get().rightMetersPerSecond, rightSpeedSetpoint);
    } else {
      leftOutput = leftSpeedSetpoint;
      rightOutput = rightSpeedSetpoint;
    }

    this.output.accept(leftOutput, rightOutput);
    this.prevSpeeds = targetWheelSpeeds;
    this.prevTime = currentTime;

    if (this.unpassedMarkers.size() > 0 && currentTime >= this.unpassedMarkers.get(0).timeSeconds) {
      PathPlannerTrajectory.EventMarker marker = this.unpassedMarkers.remove(0);

      for (String eventName : marker.names) {
        if (this.eventMap.containsKey(eventName)) {
          Command cmd = this.eventMap.get(eventName);
          new FunctionalCommand(
                  cmd::initialize,
                  cmd::execute,
                  cmd::end,
                  cmd::isFinished,
                  cmd.getRequirements().toArray(new Subsystem[0]))
              .schedule();
        }
      }
    }
  }

  @Override
  public void end(boolean interrupted) {
    this.timer.stop();

    if (interrupted) {
      this.output.accept(0.0, 0.0);
    }
  }

  @Override
  public boolean isFinished() {
    return this.timer.hasElapsed(this.trajectory.getTotalTimeSeconds());
  }
}
