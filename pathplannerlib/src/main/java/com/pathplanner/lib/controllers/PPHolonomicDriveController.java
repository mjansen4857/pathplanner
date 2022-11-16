package com.pathplanner.lib.controllers;

import com.pathplanner.lib.PathPlannerTrajectory.PathPlannerState;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

/**
 * Custom version of a @HolonomicDriveController specifically for following PathPlanner paths
 *
 * <p>This controller adds the following functionality over the WPILib version: - calculate() method
 * takes in a PathPlannerState directly - Continuous input is automatically enabled for the rotation
 * controller - Holonomic angular velocity is used as a feedforward for the rotation controller,
 * which no longer needs to be a @ProfiledPIDController
 */
public class PPHolonomicDriveController {
  private final PIDController xController;
  private final PIDController yController;
  private final PIDController rotationController;

  private Translation2d translationError = new Translation2d();
  private Rotation2d rotationError = new Rotation2d();
  private Pose2d tolerance = new Pose2d();
  private boolean isEnabled = true;

  /**
   * Constructs a PPHolonomicDriveController
   *
   * @param xController A PID controller to respond to error in the field-relative X direction
   * @param yController A PID controller to respond to error in the field-relative Y direction
   * @param rotationController A PID controller to respond to error in rotation
   */
  public PPHolonomicDriveController(
      PIDController xController, PIDController yController, PIDController rotationController) {
    this.xController = xController;
    this.yController = yController;
    this.rotationController = rotationController;

    // Auto-configure continuous input for rotation controller
    this.rotationController.enableContinuousInput(-Math.PI, Math.PI);
  }

  /**
   * Returns true if the pose error is within tolerance of the reference.
   *
   * @return True if the pose error is within tolerance of the reference.
   */
  public boolean atReference() {
    Translation2d translationTolerance = this.tolerance.getTranslation();
    Rotation2d rotationTolerance = this.tolerance.getRotation();

    return Math.abs(this.translationError.getX()) < translationTolerance.getX()
        && Math.abs(this.translationError.getY()) < translationTolerance.getY()
        && Math.abs(this.rotationError.getRadians()) < rotationTolerance.getRadians();
  }

  /**
   * Sets the pose error whic is considered tolerance for use with atReference()
   *
   * @param tolerance The pose error which is tolerable
   */
  public void setTolerance(Pose2d tolerance) {
    this.tolerance = tolerance;
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
   * Calculates the next output of the holonomic drive controller
   *
   * @param currentPose The current pose
   * @param referenceState The desired trajectory state
   * @return The next output of the holonomic drive controller
   */
  public ChassisSpeeds calculate(Pose2d currentPose, PathPlannerState referenceState) {
    double xFF =
        referenceState.velocityMetersPerSecond * referenceState.poseMeters.getRotation().getCos();
    double yFF =
        referenceState.velocityMetersPerSecond * referenceState.poseMeters.getRotation().getSin();
    double rotationFF = referenceState.holonomicAngularVelocityRadPerSec;

    this.translationError = referenceState.poseMeters.relativeTo(currentPose).getTranslation();
    this.rotationError = referenceState.holonomicRotation.minus(currentPose.getRotation());

    if (!this.isEnabled) {
      return ChassisSpeeds.fromFieldRelativeSpeeds(xFF, yFF, rotationFF, currentPose.getRotation());
    }

    double xFeedback =
        this.xController.calculate(currentPose.getX(), referenceState.poseMeters.getX());
    double yFeedback =
        this.yController.calculate(currentPose.getY(), referenceState.poseMeters.getY());
    double rotationFeedback =
        this.rotationController.calculate(
            currentPose.getRotation().getRadians(), referenceState.holonomicRotation.getRadians());

    return ChassisSpeeds.fromFieldRelativeSpeeds(
        xFF + xFeedback, yFF + yFeedback, rotationFF + rotationFeedback, currentPose.getRotation());
  }
}
