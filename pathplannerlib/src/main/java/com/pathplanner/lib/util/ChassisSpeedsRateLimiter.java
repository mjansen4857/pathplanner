package com.pathplanner.lib.util;

import edu.wpi.first.math.MathSharedStore;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.VecBuilder;
import edu.wpi.first.math.Vector;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.numbers.N2;

/**
 * Essentially a slew rate limiter for chassis speeds
 *
 * <p>This will properly apply a linear acceleration limit to the chassis speeds instead of applying
 * it separately with 2 X/Y slew rate limiters
 */
public class ChassisSpeedsRateLimiter {
  private double translationRateLimit;
  private double rotationRateLimit;

  private ChassisSpeeds prevVal;
  private double prevTime;

  /**
   * Create a new chassis speeds limiter
   *
   * @param translationRateLimit The linear acceleration limit
   * @param rotationRateLimit The angular acceleration limit
   * @param initialValue The initial chassis speeds value
   */
  public ChassisSpeedsRateLimiter(
      double translationRateLimit, double rotationRateLimit, ChassisSpeeds initialValue) {
    this.translationRateLimit = translationRateLimit;
    this.rotationRateLimit = rotationRateLimit;
    reset(initialValue);
  }

  /**
   * Create a new chassis speeds limiter
   *
   * @param translationRateLimit The linear acceleration limit
   * @param rotationRateLimit The angular acceleration limit
   */
  public ChassisSpeedsRateLimiter(double translationRateLimit, double rotationRateLimit) {
    this(translationRateLimit, rotationRateLimit, new ChassisSpeeds());
  }

  /**
   * Reset the limiter
   *
   * @param value The chassis speeds to reset with
   */
  public void reset(ChassisSpeeds value) {
    this.prevVal = value;
    this.prevTime = MathSharedStore.getTimestamp();
  }

  /**
   * Set the acceleration limits
   *
   * @param translationRateLimit Linear acceleration limit
   * @param rotationRateLimit Angular acceleration limit
   */
  public void setRateLimits(double translationRateLimit, double rotationRateLimit) {
    this.translationRateLimit = translationRateLimit;
    this.rotationRateLimit = rotationRateLimit;
  }

  /**
   * Calculate the limited chassis speeds for a given input
   *
   * @param input The target chassis speeds
   * @return The limited chassis speeds
   */
  public ChassisSpeeds calculate(ChassisSpeeds input) {
    double currentTime = MathSharedStore.getTimestamp();
    double elapsedTime = currentTime - prevTime;

    prevVal.omegaRadiansPerSecond +=
        MathUtil.clamp(
            input.omegaRadiansPerSecond - prevVal.omegaRadiansPerSecond,
            -rotationRateLimit * elapsedTime,
            rotationRateLimit * elapsedTime);

    Vector<N2> prevVelVector =
        VecBuilder.fill(prevVal.vxMetersPerSecond, prevVal.vyMetersPerSecond);
    Vector<N2> targetVelVector = VecBuilder.fill(input.vxMetersPerSecond, input.vyMetersPerSecond);
    Vector<N2> deltaVelVector = new Vector<>(targetVelVector.minus(prevVelVector));
    double maxDelta = translationRateLimit * elapsedTime;

    if (deltaVelVector.norm() > maxDelta) {
      Vector<N2> deltaUnitVector = deltaVelVector.div(deltaVelVector.norm());
      Vector<N2> limitedDelta = deltaUnitVector.times(maxDelta);
      Vector<N2> nextVelVector = new Vector<>(prevVelVector.plus(limitedDelta));

      prevVal.vxMetersPerSecond = nextVelVector.get(0, 0);
      prevVal.vyMetersPerSecond = nextVelVector.get(1, 0);
    } else {
      prevVal.vxMetersPerSecond = targetVelVector.get(0, 0);
      prevVal.vyMetersPerSecond = targetVelVector.get(1, 0);
    }

    prevTime = currentTime;
    return prevVal;
  }
}
