package com.pathplanner.lib.controllers;

import com.pathplanner.lib.path.PathPlannerTrajectory;
import com.pathplanner.lib.util.PIDConstants;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.controller.ProfiledPIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.trajectory.TrapezoidProfile;
import java.util.Optional;
import java.util.function.Supplier;

/** Path following controller for holonomic drive trains */
public class PPHolonomicDriveController implements PathFollowingController {
  private final PIDController xController;
  private final PIDController yController;
  private final ProfiledPIDController rotationController;
  private final double maxModuleSpeed;
  private final double mpsToRps;

  private Translation2d translationError = new Translation2d();
  private boolean isEnabled = true;

  private static Supplier<Optional<Rotation2d>> rotationTargetOverride = null;

  /**
   * Constructs a HolonomicDriveController
   *
   * @param translationConstants PID constants for the translation PID controllers
   * @param rotationConstants PID constants for the rotation controller
   * @param period Period of the control loop in seconds
   * @param maxModuleSpeed The max speed of a drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
   *     distance from the center of the robot to the furthest module. For mecanum, this is the
   *     drive base width / 2
   */
  public PPHolonomicDriveController(
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double period,
      double maxModuleSpeed,
      double driveBaseRadius) {
    this.xController =
        new PIDController(
            translationConstants.kP, translationConstants.kI, translationConstants.kD, period);
    this.xController.setIntegratorRange(-translationConstants.iZone, translationConstants.iZone);

    this.yController =
        new PIDController(
            translationConstants.kP, translationConstants.kI, translationConstants.kD, period);
    this.yController.setIntegratorRange(-translationConstants.iZone, translationConstants.iZone);

    // Temp rate limit of 0, will be changed in calculate
    this.rotationController =
        new ProfiledPIDController(
            rotationConstants.kP,
            rotationConstants.kI,
            rotationConstants.kD,
            new TrapezoidProfile.Constraints(0, 0),
            period);
    this.rotationController.setIntegratorRange(-rotationConstants.iZone, rotationConstants.iZone);
    this.rotationController.enableContinuousInput(-Math.PI, Math.PI);

    this.maxModuleSpeed = maxModuleSpeed;
    this.mpsToRps = 1.0 / driveBaseRadius;
  }

  /**
   * Constructs a HolonomicDriveController
   *
   * @param translationConstants PID constants for the translation PID controllers
   * @param rotationConstants PID constants for the rotation controller
   * @param maxModuleSpeed The max speed of a drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
   *     distance from the center of the robot to the furthest module. For mecanum, this is the
   *     drive base width / 2
   */
  public PPHolonomicDriveController(
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxModuleSpeed,
      double driveBaseRadius) {
    this(translationConstants, rotationConstants, 0.02, maxModuleSpeed, driveBaseRadius);
  }

  /**
   * Enables and disables the controller for troubleshooting. When calculate() is called on a
   * disabled controller, only feedforward values are returned.
   *
   * @param enabled If the controller is enabled or not
   */
  public void setEnabled(boolean enabled) {
    this.isEnabled = enabled;
  }

  /**
   * Resets the controller based on the current state of the robot
   *
   * @param currentPose Current robot pose
   * @param currentSpeeds Current robot relative chassis speeds
   */
  @Override
  public void reset(Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    rotationController.reset(
        currentPose.getRotation().getRadians(), currentSpeeds.omegaRadiansPerSecond);
  }

  /**
   * Calculates the next output of the path following controller
   *
   * @param currentPose The current robot pose
   * @param targetState The desired trajectory state
   * @return The next robot relative output of the path following controller
   */
  @Override
  public ChassisSpeeds calculateRobotRelativeSpeeds(
      Pose2d currentPose, PathPlannerTrajectory.State targetState) {
    double xFF = targetState.velocityMps * targetState.heading.getCos();
    double yFF = targetState.velocityMps * targetState.heading.getSin();

    this.translationError = currentPose.getTranslation().minus(targetState.positionMeters);

    if (!this.isEnabled) {
      return ChassisSpeeds.fromFieldRelativeSpeeds(xFF, yFF, 0, currentPose.getRotation());
    }

    double xFeedback =
        this.xController.calculate(currentPose.getX(), targetState.positionMeters.getX());
    double yFeedback =
        this.yController.calculate(currentPose.getY(), targetState.positionMeters.getY());

    double angVelConstraint = targetState.constraints.getMaxAngularVelocityRps();
    double maxAngVel = angVelConstraint;

    if (Double.isFinite(maxAngVel)) {
      // Approximation of available module speed to do rotation with
      double maxAngVelModule = Math.max(0, maxModuleSpeed - targetState.velocityMps) * mpsToRps;
      maxAngVel = Math.min(angVelConstraint, maxAngVelModule);
    }

    var rotationConstraints =
        new TrapezoidProfile.Constraints(
            maxAngVel, targetState.constraints.getMaxAngularAccelerationRpsSq());

    Rotation2d targetRotation = targetState.targetHolonomicRotation;
    if (rotationTargetOverride != null) {
      targetRotation = rotationTargetOverride.get().orElse(targetRotation);
    }

    double rotationFeedback =
        rotationController.calculate(
            currentPose.getRotation().getRadians(),
            new TrapezoidProfile.State(targetRotation.getRadians(), 0),
            rotationConstraints);
    double rotationFF =
        targetState.holonomicAngularVelocityRps.orElse(rotationController.getSetpoint().velocity);

    return ChassisSpeeds.fromFieldRelativeSpeeds(
        xFF + xFeedback, yFF + yFeedback, rotationFF + rotationFeedback, currentPose.getRotation());
  }

  /**
   * Get the current positional error between the robot's actual and target positions
   *
   * @return Positional error, in meters
   */
  @Override
  public double getPositionalError() {
    return translationError.getNorm();
  }

  /**
   * Is this controller for holonomic drivetrains? Used to handle some differences in functionality
   * in the path following command.
   *
   * @return True if this controller is for a holonomic drive train
   */
  @Override
  public boolean isHolonomic() {
    return true;
  }

  /**
   * Set a supplier that will be used to override the rotation target when path following.
   *
   * <p>This function should return an empty optional to use the rotation targets in the path
   *
   * @param rotationTargetOverride Supplier to override rotation targets
   */
  public static void setRotationTargetOverride(
      Supplier<Optional<Rotation2d>> rotationTargetOverride) {
    PPHolonomicDriveController.rotationTargetOverride = rotationTargetOverride;
  }
}
