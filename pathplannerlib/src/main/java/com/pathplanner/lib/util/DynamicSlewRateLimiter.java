package com.pathplanner.lib.util;

import edu.wpi.first.math.MathSharedStore;
import edu.wpi.first.math.MathUtil;

/** Slew rate limiter that allows changing the rate limit */
public class DynamicSlewRateLimiter {
  private double rateLimit;

  private double prevVal;
  private double prevTime;

  /**
   * Create a new dynamic slew rate limiter
   *
   * @param rateLimit The rate limit
   * @param initalValue Initial value
   */
  public DynamicSlewRateLimiter(double rateLimit, double initalValue) {
    this.rateLimit = rateLimit;
    this.prevVal = initalValue;
    this.prevTime = MathSharedStore.getTimestamp();
  }

  /**
   * Create a new dynamic slew rate limiter
   *
   * @param rateLimit The rate limit
   */
  public DynamicSlewRateLimiter(double rateLimit) {
    this(rateLimit, 0);
  }

  /**
   * Reset the limiter
   *
   * @param value The current value
   */
  public void reset(double value) {
    prevVal = value;
    prevTime = MathSharedStore.getTimestamp();
  }

  /**
   * Set the limiter's rate limit
   *
   * @param rateLimit The rate limit
   */
  public void setRateLimit(double rateLimit) {
    this.rateLimit = rateLimit;
  }

  /**
   * Calculate the next value
   *
   * @param input The input to the limiter
   * @return Input, limited to a max rate of change by the rate limit
   */
  public double calculate(double input) {
    double currentTime = MathSharedStore.getTimestamp();
    double elapsedTime = currentTime - prevTime;
    prevTime = currentTime;

    prevVal += MathUtil.clamp(input - prevVal, -rateLimit * elapsedTime, rateLimit * elapsedTime);

    return prevVal;
  }
}
