package com.pathplanner.lib.util;

import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.interpolation.Interpolatable;

/**
 * Collection of different feedforward values for a drive motor/module
 *
 * @param accelerationMPS Linear acceleration at the wheel in meters per second
 * @param forceNewtons Linear force applied by the motor at the wheel in newtons
 * @param torqueCurrentAmps Torque-current of the motor in amps
 */
public record DriveFeedforward(
    double accelerationMPS, double forceNewtons, double torqueCurrentAmps)
    implements Interpolatable<DriveFeedforward> {
  @Override
  public DriveFeedforward interpolate(DriveFeedforward endValue, double t) {
    return new DriveFeedforward(
        MathUtil.interpolate(accelerationMPS, endValue.accelerationMPS, t),
        MathUtil.interpolate(forceNewtons, endValue.forceNewtons, t),
        MathUtil.interpolate(torqueCurrentAmps, endValue.torqueCurrentAmps, t));
  }

  /**
   * Reverse the feedforwards for driving backwards.
   *
   * @return Reversed feedforwards
   */
  public DriveFeedforward reverse() {
    return new DriveFeedforward(-accelerationMPS, -forceNewtons, -torqueCurrentAmps);
  }
}
