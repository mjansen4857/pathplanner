package com.pathplanner.lib.controllers;

import com.pathplanner.lib.config.PIDConstants;
import com.pathplanner.lib.trajectory.PathPlannerTrajectoryState;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import java.util.Optional;
import java.util.function.DoubleSupplier;
import java.util.function.Supplier;

/** Path following controller for holonomic drive trains */
public class PPHolonomicDriveController implements PathFollowingController {
  private final PIDController xController;
  private final PIDController yController;
  private final PIDController rotationController;

  private Translation2d translationError = new Translation2d();
  private boolean isEnabled = true;

  private static Supplier<Optional<Rotation2d>> rotationTargetOverride = null;
  private static DoubleSupplier xFeedbackOverride = null;
  private static DoubleSupplier yFeedbackOverride = null;
  private static DoubleSupplier rotFeedbackOverride = null;

  /**
   * Constructs a HolonomicDriveController
   *
   * @param translationConstants PID constants for the translation PID controllers
   * @param rotationConstants PID constants for the rotation controller
   * @param period Period of the control loop in seconds
   */
  public PPHolonomicDriveController(
      PIDConstants translationConstants, PIDConstants rotationConstants, double period) {
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
        new PIDController(rotationConstants.kP, rotationConstants.kI, rotationConstants.kD, period);
    this.rotationController.setIntegratorRange(-rotationConstants.iZone, rotationConstants.iZone);
    this.rotationController.enableContinuousInput(-Math.PI, Math.PI);
  }

  /**
   * Constructs a HolonomicDriveController
   *
   * @param translationConstants PID constants for the translation PID controllers
   * @param rotationConstants PID constants for the rotation controller
   */
  public PPHolonomicDriveController(
      PIDConstants translationConstants, PIDConstants rotationConstants) {
    this(translationConstants, rotationConstants, 0.02);
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
    xController.reset();
    yController.reset();
    rotationController.reset();
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
      Pose2d currentPose, PathPlannerTrajectoryState targetState) {
    double xFF = targetState.fieldSpeeds.vxMetersPerSecond;
    double yFF = targetState.fieldSpeeds.vyMetersPerSecond;

    this.translationError = currentPose.getTranslation().minus(targetState.pose.getTranslation());

    if (!this.isEnabled) {
      return ChassisSpeeds.fromFieldRelativeSpeeds(xFF, yFF, 0, currentPose.getRotation());
    }

    double xFeedback = this.xController.calculate(currentPose.getX(), targetState.pose.getX());
    double yFeedback = this.yController.calculate(currentPose.getY(), targetState.pose.getY());

    Rotation2d targetRotation = targetState.pose.getRotation();
    if (rotationTargetOverride != null) {
      targetRotation = rotationTargetOverride.get().orElse(targetRotation);
    }

    double rotationFeedback =
        rotationController.calculate(
            currentPose.getRotation().getRadians(), targetRotation.getRadians());
    double rotationFF = targetState.fieldSpeeds.omegaRadiansPerSecond;

    if (xFeedbackOverride != null) {
      xFeedback = xFeedbackOverride.getAsDouble();
    }
    if (yFeedbackOverride != null) {
      yFeedback = yFeedbackOverride.getAsDouble();
    }
    if (rotFeedbackOverride != null) {
      rotationFeedback = rotFeedbackOverride.getAsDouble();
    }

    return ChassisSpeeds.fromFieldRelativeSpeeds(
        xFF + xFeedback, yFF + yFeedback, rotationFF + rotationFeedback, currentPose.getRotation());
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
   * @deprecated Use overrideRotationFeedback instead, with the output of your own PID controller
   */
  @Deprecated
  public static void setRotationTargetOverride(
      Supplier<Optional<Rotation2d>> rotationTargetOverride) {
    PPHolonomicDriveController.rotationTargetOverride = rotationTargetOverride;
  }

  /**
   * Begin overriding the X axis feedback.
   *
   * @param xFeedbackOverride Double supplier that returns the desired FIELD-RELATIVE X feedback in
   *     meters/sec
   */
  public static void overrideXFeedback(DoubleSupplier xFeedbackOverride) {
    PPHolonomicDriveController.xFeedbackOverride = xFeedbackOverride;
  }

  /**
   * Stop overriding the X axis feedback, and return to calculating it based on path following
   * error.
   */
  public static void clearXFeedbackOverride() {
    PPHolonomicDriveController.xFeedbackOverride = null;
  }

  /**
   * Begin overriding the Y axis feedback.
   *
   * @param yFeedbackOverride Double supplier that returns the desired FIELD-RELATIVE Y feedback in
   *     meters/sec
   */
  public static void overrideYFeedback(DoubleSupplier yFeedbackOverride) {
    PPHolonomicDriveController.yFeedbackOverride = yFeedbackOverride;
  }

  /**
   * Stop overriding the Y axis feedback, and return to calculating it based on path following
   * error.
   */
  public static void clearYFeedbackOverride() {
    PPHolonomicDriveController.yFeedbackOverride = null;
  }

  /**
   * Begin overriding the X and Y axis feedback.
   *
   * @param xFeedbackOverride Double supplier that returns the desired FIELD-RELATIVE X feedback in
   *     meters/sec
   * @param yFeedbackOverride Double supplier that returns the desired FIELD-RELATIVE Y feedback in
   *     meters/sec
   */
  public static void overrideXYFeedback(
      DoubleSupplier xFeedbackOverride, DoubleSupplier yFeedbackOverride) {
    overrideXFeedback(xFeedbackOverride);
    overrideYFeedback(yFeedbackOverride);
  }

  /**
   * Stop overriding the X and Y axis feedback, and return to calculating them based on path
   * following error.
   */
  public static void clearXYFeedbackOverride() {
    clearXFeedbackOverride();
    clearYFeedbackOverride();
  }

  /**
   * Begin overriding the rotation feedback.
   *
   * @param rotationFeedbackOverride Double supplier that returns the desired rotation feedback in
   *     radians/sec
   */
  public static void overrideRotationFeedback(DoubleSupplier rotationFeedbackOverride) {
    PPHolonomicDriveController.rotFeedbackOverride = rotationFeedbackOverride;
  }

  /**
   * Stop overriding the rotation feedback, and return to calculating it based on path following
   * error.
   */
  public static void clearRotationFeedbackOverride() {
    PPHolonomicDriveController.rotFeedbackOverride = null;
  }

  /** Clear all feedback overrides and return to purely using path following error for feedback */
  public static void clearFeedbackOverrides() {
    clearXYFeedbackOverride();
    clearRotationFeedbackOverride();
  }
}
