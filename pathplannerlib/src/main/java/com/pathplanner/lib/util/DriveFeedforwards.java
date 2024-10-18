package com.pathplanner.lib.util;

import static edu.wpi.first.units.Units.*;

import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.interpolation.Interpolatable;
import edu.wpi.first.units.measure.Current;
import edu.wpi.first.units.measure.Force;
import edu.wpi.first.units.measure.LinearAcceleration;
import java.util.Arrays;

/**
 * Collection of different feedforward values for each drive module. If using swerve, these values
 * will all be in FL, FR, BL, BR order. If using a differential drive, these will be in L, R order.
 *
 * @param accelerationsMPSSq Linear acceleration at the wheels in meters per second
 * @param linearForcesNewtons Linear force applied by the motors at the wheels in newtons
 * @param torqueCurrentsAmps Torque-current of the drive motors in amps
 * @param robotRelativeForcesXNewtons X components of robot-relative force vectors for the wheels in
 *     newtons. The magnitude of these vectors will typically be greater than the linear force
 *     feedforwards due to friction forces.
 * @param robotRelativeForcesYNewtons X components of robot-relative force vectors for the wheels in
 *     newtons. The magnitude of these vectors will typically be greater than the linear force
 *     feedforwards due to friction forces.
 */
public record DriveFeedforwards(
    double[] accelerationsMPSSq,
    double[] linearForcesNewtons,
    double[] torqueCurrentsAmps,
    double[] robotRelativeForcesXNewtons,
    double[] robotRelativeForcesYNewtons)
    implements Interpolatable<DriveFeedforwards> {
  /**
   * Collection of different feedforward values for each drive module. If using swerve, these values
   * will all be in FL, FR, BL, BR order. If using a differential drive, these will be in L, R
   * order.
   *
   * @param accelerations Linear acceleration at the wheels
   * @param linearForces Linear force applied by the motors at the wheels
   * @param torqueCurrents Torque-current of the drive motors
   * @param robotRelativeForcesX X components of robot-relative force vectors for the wheels. The
   *     magnitude of these vectors will typically be greater than the linear force feedforwards due
   *     to friction forces.
   * @param robotRelativeForcesY X components of robot-relative force vectors for the wheels. The
   *     magnitude of these vectors will typically be greater than the linear force feedforwards due
   *     to friction forces.
   */
  public DriveFeedforwards(
      LinearAcceleration[] accelerations,
      Force[] linearForces,
      Current[] torqueCurrents,
      Force[] robotRelativeForcesX,
      Force[] robotRelativeForcesY) {
    this(
        Arrays.stream(accelerations).mapToDouble(x -> x.in(MetersPerSecondPerSecond)).toArray(),
        Arrays.stream(linearForces).mapToDouble(x -> x.in(Newtons)).toArray(),
        Arrays.stream(torqueCurrents).mapToDouble(x -> x.in(Amps)).toArray(),
        Arrays.stream(robotRelativeForcesX).mapToDouble(x -> x.in(Newtons)).toArray(),
        Arrays.stream(robotRelativeForcesY).mapToDouble(x -> x.in(Newtons)).toArray());
  }

  /**
   * Create drive feedforwards consisting of all zeros
   *
   * @param numModules Number of drive modules
   * @return Zero feedforwards
   */
  public static DriveFeedforwards zeros(int numModules) {
    return new DriveFeedforwards(
        new double[numModules],
        new double[numModules],
        new double[numModules],
        new double[numModules],
        new double[numModules]);
  }

  @Override
  public DriveFeedforwards interpolate(DriveFeedforwards endValue, double t) {
    return new DriveFeedforwards(
        interpolateArray(accelerationsMPSSq, endValue.accelerationsMPSSq, t),
        interpolateArray(linearForcesNewtons, endValue.linearForcesNewtons, t),
        interpolateArray(torqueCurrentsAmps, endValue.torqueCurrentsAmps, t),
        interpolateArray(robotRelativeForcesXNewtons, endValue.robotRelativeForcesXNewtons, t),
        interpolateArray(robotRelativeForcesYNewtons, endValue.robotRelativeForcesYNewtons, t));
  }

  /**
   * Reverse the feedforwards for driving backwards. This should only be used for differential drive
   * robots.
   *
   * @return Reversed feedforwards
   */
  public DriveFeedforwards reverse() {
    if (accelerationsMPSSq.length != 2) {
      throw new IllegalStateException(
          "Feedforwards should only be reversed for differential drive trains");
    }

    return new DriveFeedforwards(
        new double[] {-accelerationsMPSSq[1], -accelerationsMPSSq[0]},
        new double[] {-linearForcesNewtons[1], -linearForcesNewtons[0]},
        new double[] {-torqueCurrentsAmps[1], -torqueCurrentsAmps[0]},
        new double[] {-robotRelativeForcesXNewtons[1], -robotRelativeForcesXNewtons[0]},
        new double[] {-robotRelativeForcesYNewtons[1], -robotRelativeForcesYNewtons[0]});
  }

  /**
   * Flip the feedforwards for the other side of the field. Only does anything if mirrored symmetry
   * is used
   *
   * @return Flipped feedforwards
   */
  public DriveFeedforwards flip() {
    return new DriveFeedforwards(
        FlippingUtil.flipFeedforwards(accelerationsMPSSq),
        FlippingUtil.flipFeedforwards(linearForcesNewtons),
        FlippingUtil.flipFeedforwards(torqueCurrentsAmps),
        FlippingUtil.flipFeedforwards(robotRelativeForcesXNewtons),
        FlippingUtil.flipFeedforwards(robotRelativeForcesYNewtons));
  }

  /**
   * Get the linear accelerations at the wheels
   *
   * @return Linear accelerations at the wheels
   */
  public LinearAcceleration[] accelerations() {
    return Arrays.stream(accelerationsMPSSq)
        .mapToObj(MetersPerSecondPerSecond::of)
        .toArray(LinearAcceleration[]::new);
  }

  /**
   * Get the linear forces at the wheels
   *
   * @return Linear forces at the wheels
   */
  public Force[] linearForces() {
    return Arrays.stream(linearForcesNewtons).mapToObj(Newtons::of).toArray(Force[]::new);
  }

  /**
   * Get the torque-current of the drive motors
   *
   * @return Torque-current of the drive motors
   */
  public Current[] torqueCurrents() {
    return Arrays.stream(torqueCurrentsAmps).mapToObj(Amps::of).toArray(Current[]::new);
  }

  /**
   * Get the X components of the robot-relative force vectors at the wheels
   *
   * @return X components of the robot-relative force vectors at the wheels
   */
  public Force[] robotRelativeForcesX() {
    return Arrays.stream(robotRelativeForcesXNewtons).mapToObj(Newtons::of).toArray(Force[]::new);
  }

  /**
   * Get the Y components of the robot-relative force vectors at the wheels
   *
   * @return Y components of the robot-relative force vectors at the wheels
   */
  public Force[] robotRelativeForcesY() {
    return Arrays.stream(robotRelativeForcesYNewtons).mapToObj(Newtons::of).toArray(Force[]::new);
  }

  private static double[] interpolateArray(double[] a, double[] b, double t) {
    double[] ret = new double[a.length];
    for (int i = 0; i < a.length; i++) {
      ret[i] = MathUtil.interpolate(a[i], b[i], t);
    }
    return ret;
  }
}
