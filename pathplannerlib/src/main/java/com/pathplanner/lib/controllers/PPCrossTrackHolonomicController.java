package com.pathplanner.lib.controllers;

import com.pathplanner.lib.config.PIDConstants;
import com.pathplanner.lib.trajectory.PathPlannerTrajectoryState;
import edu.wpi.first.math.MathUtil;
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
  private final double alongTrackKp;
  private final PIDController rotationController;
  private final double curvatureFfGain;
  private final double period;

  // Above this tangent-rotation rate, suppress the cross-track D-term and curvature FF -- both
  // would sense frame rotation as robot motion. Above smooth FRC paths (~4 rad/s at v=4 m/s on
  // a 1 m radius), below cusp/discontinuity rates (10+ rad/s).
  private static final double TANGENT_RATE_THRESHOLD_RAD_PER_SEC = 5.0;

  private double lastCrossTrackError = 0.0;
  private boolean hasLastError = false;
  private Rotation2d lastTangentHeading = null;

  /**
   * Construct a cross-track holonomic controller with full configuration.
   *
   * @param crossTrackConstants PID constants for cross-track (perpendicular-to-tangent) correction.
   *     Only kP and kD are used (cross-track is 1D and reset every cycle, so kI/iZone are ignored).
   * @param alongTrackKp Proportional gain for along-track (tangent-direction) correction. Adds
   *     extra tangent-direction velocity proportional to tangent-direction lag, so the robot
   *     catches up to the target sample when it falls behind. Set to 0 to disable.
   * @param rotationConstants PID constants for the rotation controller. All fields used.
   * @param curvatureFfGain Centripetal feedforward gain, in seconds. Applied as a
   *     perpendicular-to-tangent velocity offset of magnitude {@code gain * v^2 * kappa} to counter
   *     outward drift on curves. Set to 0 to disable.
   * @param period Control-loop period in seconds.
   */
  public PPCrossTrackHolonomicController(
      PIDConstants crossTrackConstants,
      double alongTrackKp,
      PIDConstants rotationConstants,
      double curvatureFfGain,
      double period) {
    this.crossTrackKp = crossTrackConstants.kP;
    this.crossTrackKd = crossTrackConstants.kD;
    this.alongTrackKp = alongTrackKp;
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
   * @param alongTrackKp Along-track proportional gain (0 to disable).
   * @param rotationConstants Rotation PID constants.
   * @param curvatureFfGain Curvature feedforward gain in seconds.
   */
  public PPCrossTrackHolonomicController(
      PIDConstants crossTrackConstants,
      double alongTrackKp,
      PIDConstants rotationConstants,
      double curvatureFfGain) {
    this(crossTrackConstants, alongTrackKp, rotationConstants, curvatureFfGain, 0.02);
  }

  /**
   * Construct a cross-track holonomic controller without along-track correction. Use this if your
   * path's velocity profile is reliable enough that tangent-direction tracking comes "for free"
   * from the planned {@code targetState.fieldSpeeds} feedforward.
   *
   * @param crossTrackConstants Cross-track PD constants.
   * @param rotationConstants Rotation PID constants.
   * @param curvatureFfGain Curvature FF gain.
   */
  public PPCrossTrackHolonomicController(
      PIDConstants crossTrackConstants, PIDConstants rotationConstants, double curvatureFfGain) {
    this(crossTrackConstants, 0.0, rotationConstants, curvatureFfGain, 0.02);
  }

  /**
   * Construct a cross-track holonomic controller with the tuning values validated on the reference
   * FRC swerve: crossTrackKp=3.0, crossTrackKd=0.5, alongTrackKp=2.0, rotationKp=5.0,
   * curvatureFfGain=0.1.
   *
   * @return Controller with default tuning
   */
  public static PPCrossTrackHolonomicController defaults() {
    return new PPCrossTrackHolonomicController(
        new PIDConstants(3.0, 0.0, 0.5), 2.0, new PIDConstants(5.0, 0.0, 0.0), 0.1);
  }

  @Override
  public void reset(Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    rotationController.reset();
    lastCrossTrackError = 0.0;
    hasLastError = false;
    lastTangentHeading = null;
  }

  @Override
  public ChassisSpeeds calculateRobotRelativeSpeeds(
      Pose2d currentPose, PathPlannerTrajectoryState targetState) {
    Rotation2d tangent = targetState.heading;
    double tx = tangent.getCos();
    double ty = tangent.getSin();
    // Left-perpendicular to tangent (90 deg CCW).
    double nx = -ty;
    double ny = tx;

    // Suppress D-term and curvature FF when the tangent frame rotates faster than the robot
    // (cusps, U-turns, sharp corners) -- both would sense frame motion as robot motion.
    boolean tangentFlipped = false;
    if (lastTangentHeading != null) {
      double headingDelta =
          MathUtil.angleModulus(tangent.getRadians() - lastTangentHeading.getRadians());
      tangentFlipped = Math.abs(headingDelta / period) > TANGENT_RATE_THRESHOLD_RAD_PER_SEC;
    }
    lastTangentHeading = tangent;

    // Decompose (robot - target) into along-track (+ = ahead) and cross-track (+ = left of
    // tangent).
    Translation2d delta = currentPose.getTranslation().minus(targetState.pose.getTranslation());
    double alongTrackError = delta.getX() * tx + delta.getY() * ty;
    double crossTrackError = delta.getX() * nx + delta.getY() * ny;

    // Cross-track rate: finite-difference, zeroed on first sample and across tangent flips.
    double crossTrackRate;
    if (hasLastError && !tangentFlipped) {
      crossTrackRate = (crossTrackError - lastCrossTrackError) / period;
    } else {
      crossTrackRate = 0.0;
    }
    lastCrossTrackError = crossTrackError;
    hasLastError = true;

    // Negate: pulls robot toward path.
    double crossTrackCorrection = -(crossTrackKp * crossTrackError + crossTrackKd * crossTrackRate);

    // Along-track P gives a recovery term when the planned-v FF alone leaves the robot lagging.
    double alongTrackCorrection = -alongTrackKp * alongTrackError;

    // Centripetal FF: gain * v^2 * kappa. Suppressed across tangent discontinuities.
    double v = targetState.linearVelocity;
    double curvatureFf =
        tangentFlipped ? 0.0 : (curvatureFfGain * v * v * targetState.curvatureRadPerMeter);

    double perpVelocity = crossTrackCorrection + curvatureFf;

    // Sum in field frame: planned FF + along-track (tangent) + perp (normal).
    double vxField =
        targetState.fieldSpeeds.vxMetersPerSecond + alongTrackCorrection * tx + perpVelocity * nx;
    double vyField =
        targetState.fieldSpeeds.vyMetersPerSecond + alongTrackCorrection * ty + perpVelocity * ny;

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
