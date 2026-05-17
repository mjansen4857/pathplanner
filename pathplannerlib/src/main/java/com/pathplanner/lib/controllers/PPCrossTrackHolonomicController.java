package com.pathplanner.lib.controllers;

import com.pathplanner.lib.config.PIDConstants;
import com.pathplanner.lib.trajectory.PathPlannerTrajectoryState;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

/**
 * Holonomic path-following controller that applies cross-track PD on the perpendicular-to-tangent
 * error rather than per-axis PID, plus a curvature feedforward to anticipate centripetal drift on
 * curves. The tangent-direction velocity comes from {@code targetState.fieldSpeeds} as a
 * feedforward; rotation is closed-loop PID against the target holonomic rotation.
 *
 * <p>Designed to be paired with {@link com.pathplanner.lib.commands.FollowPathDistanceCommand},
 * which samples the trajectory by arc length and feeds a projected target state to this controller.
 *
 * <p>Differences vs {@link PPHolonomicDriveController}:
 *
 * <ul>
 *   <li>Cross-track (1D, perpendicular to path) PD instead of independent x/y PID, so the
 *       controller doesn't fight the planned tangent-direction velocity
 *   <li>Optional curvature feedforward to reduce steady-state lateral error on curves
 * </ul>
 */
public class PPCrossTrackHolonomicController implements PathFollowingController {
  private final double crossTrackKp;
  private final double crossTrackKd;
  private final PIDController rotationController;
  private final double curvatureFfGain;
  private final double period;

  private double lastCrossTrackError = 0.0;
  private boolean hasLastError = false;

  /**
   * Construct a cross-track holonomic controller with full configuration.
   *
   * @param crossTrackConstants PID constants for cross-track correction. Only kP and kD are used
   *     (cross-track is 1D and reset every cycle, so kI/iZone are ignored).
   * @param rotationConstants PID constants for the rotation controller. All fields used.
   * @param curvatureFfGain Centripetal feedforward gain, in seconds. Applied as a
   *     perpendicular-to-tangent velocity offset of magnitude {@code gain * v^2 * kappa} to counter
   *     outward drift on curves. Set to 0 to disable.
   * @param period Control-loop period in seconds.
   */
  public PPCrossTrackHolonomicController(
      PIDConstants crossTrackConstants,
      PIDConstants rotationConstants,
      double curvatureFfGain,
      double period) {
    this.crossTrackKp = crossTrackConstants.kP;
    this.crossTrackKd = crossTrackConstants.kD;
    this.rotationController =
        new PIDController(rotationConstants.kP, rotationConstants.kI, rotationConstants.kD, period);
    this.rotationController.setIntegratorRange(-rotationConstants.iZone, rotationConstants.iZone);
    this.rotationController.enableContinuousInput(-Math.PI, Math.PI);
    this.curvatureFfGain = curvatureFfGain;
    this.period = period;
  }

  /**
   * Construct a cross-track holonomic controller with a default 20 ms period.
   *
   * @param crossTrackConstants Cross-track PD constants (kI/iZone ignored).
   * @param rotationConstants Rotation PID constants.
   * @param curvatureFfGain Curvature feedforward gain in seconds.
   */
  public PPCrossTrackHolonomicController(
      PIDConstants crossTrackConstants, PIDConstants rotationConstants, double curvatureFfGain) {
    this(crossTrackConstants, rotationConstants, curvatureFfGain, 0.02);
  }

  /**
   * Construct a cross-track holonomic controller with the tuning values validated on the reference
   * FRC swerve: crossTrackKp=3.0, crossTrackKd=0.5, rotationKp=5.0, curvatureFfGain=0.1.
   *
   * @return Controller with default tuning
   */
  public static PPCrossTrackHolonomicController defaults() {
    return new PPCrossTrackHolonomicController(
        new PIDConstants(3.0, 0.0, 0.5), new PIDConstants(5.0, 0.0, 0.0), 0.1);
  }

  @Override
  public void reset(Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    rotationController.reset();
    lastCrossTrackError = 0.0;
    hasLastError = false;
  }

  @Override
  public ChassisSpeeds calculateRobotRelativeSpeeds(
      Pose2d currentPose, PathPlannerTrajectoryState targetState) {
    // Tangent direction of travel along the path at the target sample.
    Rotation2d tangent = targetState.heading;
    double tx = tangent.getCos();
    double ty = tangent.getSin();
    // Left-perpendicular to tangent (90 deg CCW).
    double nx = -ty;
    double ny = tx;

    // Signed cross-track error: positive if robot is left of the path tangent.
    Translation2d delta = currentPose.getTranslation().minus(targetState.pose.getTranslation());
    double crossTrackError = delta.getX() * nx + delta.getY() * ny;

    // Finite-difference rate. Initialized to 0 on the first sample to avoid a spurious kick.
    double crossTrackRate;
    if (hasLastError) {
      crossTrackRate = (crossTrackError - lastCrossTrackError) / period;
    } else {
      crossTrackRate = 0.0;
    }
    lastCrossTrackError = crossTrackError;
    hasLastError = true;

    // Cross-track correction pulls the robot back toward the path (so subtract the error).
    double crossTrackCorrection = -(crossTrackKp * crossTrackError + crossTrackKd * crossTrackRate);

    // Curvature FF anticipates centripetal drift: extra perpendicular velocity = gain * v^2 * kappa
    double v = targetState.linearVelocity;
    double curvatureFf = curvatureFfGain * v * v * targetState.curvatureRadPerMeter;

    double perpVelocity = crossTrackCorrection + curvatureFf;

    // Sum tangent FF velocity + perpendicular correction (field frame).
    double vxField = targetState.fieldSpeeds.vxMetersPerSecond + perpVelocity * nx;
    double vyField = targetState.fieldSpeeds.vyMetersPerSecond + perpVelocity * ny;

    // Heading PID against target holonomic rotation, plus rotational FF from planned omega.
    double rotationFeedback =
        rotationController.calculate(
            currentPose.getRotation().getRadians(), targetState.pose.getRotation().getRadians());
    double omega = targetState.fieldSpeeds.omegaRadiansPerSecond + rotationFeedback;

    return ChassisSpeeds.fromFieldRelativeSpeeds(
        vxField, vyField, omega, currentPose.getRotation());
  }

  @Override
  public boolean isHolonomic() {
    return true;
  }
}
