package com.pathplanner.lib.controllers;

import com.pathplanner.lib.path.PathPlannerTrajectory;
import com.pathplanner.lib.util.DynamicSlewRateLimiter;
import com.pathplanner.lib.util.PIDConstants;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

public class HolonomicDriveController {
  private final PIDController xController;
  private final PIDController yController;
  private final PIDController rotationController;
  private final DynamicSlewRateLimiter angularVelLimiter;
  private final double maxModuleSpeed;
  private final double mpsToRps;

  private Translation2d translationError = new Translation2d();
  private boolean isEnabled = true;

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
  public HolonomicDriveController(
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

    this.rotationController =
        new PIDController(rotationConstants.kP, rotationConstants.kI, rotationConstants.kD, period);
    this.rotationController.setIntegratorRange(-rotationConstants.iZone, rotationConstants.iZone);
    this.rotationController.enableContinuousInput(-Math.PI, Math.PI);

    // Temp rate limit of 0, will be changed in calculate
    this.angularVelLimiter = new DynamicSlewRateLimiter(0);

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
  public HolonomicDriveController(
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

  public void reset(ChassisSpeeds currentSpeeds) {
    angularVelLimiter.reset(currentSpeeds.omegaRadiansPerSecond);
  }

  /**
   * Calculates the next output of the holonomic drive controller
   *
   * @param currentPose The current pose
   * @param referenceState The desired trajectory state
   * @return The next output of the holonomic drive controller (robot relative)
   */
  public ChassisSpeeds calculate(Pose2d currentPose, PathPlannerTrajectory.State referenceState) {
    double xFF = referenceState.velocityMps * referenceState.heading.getCos();
    double yFF = referenceState.velocityMps * referenceState.heading.getSin();

    this.translationError = currentPose.getTranslation().minus(referenceState.positionMeters);

    if (!this.isEnabled) {
      return ChassisSpeeds.fromFieldRelativeSpeeds(xFF, yFF, 0, currentPose.getRotation());
    }

    double xFeedback =
        this.xController.calculate(currentPose.getX(), referenceState.positionMeters.getX());
    double yFeedback =
        this.yController.calculate(currentPose.getY(), referenceState.positionMeters.getY());

    double angVelConstraint = referenceState.constraints.getMaxAngularVelocityRps();
    angularVelLimiter.setRateLimit(referenceState.constraints.getMaxAngularAccelerationRpsSq());

    // Approximation of available module speed to do rotation with
    double maxAngVelModule = Math.max(0, maxModuleSpeed - referenceState.velocityMps) * mpsToRps;

    double maxAngVel = Math.min(angVelConstraint, maxAngVelModule);

    double targetRotationVel =
        this.rotationController.calculate(
            currentPose.getRotation().getRadians(),
            referenceState.targetHolonomicRotation.getRadians());
    targetRotationVel = MathUtil.clamp(targetRotationVel, -maxAngVel, maxAngVel);

    return ChassisSpeeds.fromFieldRelativeSpeeds(
        xFF + xFeedback,
        yFF + yFeedback,
        angularVelLimiter.calculate(targetRotationVel),
        currentPose.getRotation());
  }

  /**
   * Get the last positional error of the controller
   *
   * @return Positional error, in meters
   */
  public double getPositionalError() {
    return translationError.getNorm();
  }
}
