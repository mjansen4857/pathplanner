package com.pathplanner.lib.util;

import static edu.wpi.first.units.Units.*;

import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.interpolation.Interpolatable;
import edu.wpi.first.units.measure.Current;
import edu.wpi.first.units.measure.Force;
import edu.wpi.first.units.measure.LinearAcceleration;

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
  /**
   * Collection of different feedforward values for a drive motor/module
   *
   * @param acceleration Linear acceleration at the wheel
   * @param force Linear force applied by the motor at the wheel
   * @param torqueCurrent Torque-current of the motor
   */
  public DriveFeedforward(LinearAcceleration acceleration, Force force, Current torqueCurrent) {
    this(acceleration.in(MetersPerSecondPerSecond), force.in(Newtons), torqueCurrent.in(Amps));
  }

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

  /**
   * Get the linear acceleration at the wheel
   *
   * @return Linear acceleration at the wheel
   */
  public LinearAcceleration acceleration() {
    return MetersPerSecondPerSecond.of(accelerationMPS);
  }

  /**
   * Get the linear force at the wheel
   *
   * @return Linear force at the wheel
   */
  public Force force() {
    return Newtons.of(forceNewtons);
  }

  /**
   * Get the torque-current of the motor
   *
   * @return Torque-current of the motor
   */
  public Current torqueCurrent() {
    return Amps.of(torqueCurrentAmps);
  }
}
