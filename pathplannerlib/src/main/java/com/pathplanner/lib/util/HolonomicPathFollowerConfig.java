package com.pathplanner.lib.util;

/** Configuration for the holonomic path following commands */
public class HolonomicPathFollowerConfig {
  /** PIDConstants used for translation PID controllers */
  public final PIDConstants translationConstants;
  /** PIDConstants used for rotation PID controllers */
  public final PIDConstants rotationConstants;
  /** Max speed of a drive module in m/s */
  public final double maxModuleSpeed;
  /** Radius of the drive base in meters */
  public final double driveBaseRadius;
  /** Path replanning config */
  public final ReplanningConfig replanningConfig;
  /** Period of the robot control loop in seconds */
  public final double period;

  /**
   * Create a new holonomic path follower config
   *
   * @param translationConstants {@link com.pathplanner.lib.util.PIDConstants} used for creating the
   *     translation PID controllers
   * @param rotationConstants {@link com.pathplanner.lib.util.PIDConstants} used for creating the
   *     rotation PID controller
   * @param maxModuleSpeed Max speed of an individual drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. This is the distance from the
   *     center of the robot to the furthest module.
   * @param replanningConfig Path replanning configuration
   * @param period Control loop period in seconds (Default = 0.02)
   */
  public HolonomicPathFollowerConfig(
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxModuleSpeed,
      double driveBaseRadius,
      ReplanningConfig replanningConfig,
      double period) {
    this.translationConstants = translationConstants;
    this.rotationConstants = rotationConstants;
    this.maxModuleSpeed = maxModuleSpeed;
    this.driveBaseRadius = driveBaseRadius;
    this.replanningConfig = replanningConfig;
    this.period = period;
  }

  /**
   * Create a new holonomic path follower config
   *
   * @param translationConstants {@link com.pathplanner.lib.util.PIDConstants} used for creating the
   *     translation PID controllers
   * @param rotationConstants {@link com.pathplanner.lib.util.PIDConstants} used for creating the
   *     rotation PID controller
   * @param maxModuleSpeed Max speed of an individual drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
   *     distance from the center of the robot to the furthest module. For mecanum, this is the
   *     drive base width / 2
   * @param replanningConfig Path replanning configuration
   */
  public HolonomicPathFollowerConfig(
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxModuleSpeed,
      double driveBaseRadius,
      ReplanningConfig replanningConfig) {
    this(
        translationConstants,
        rotationConstants,
        maxModuleSpeed,
        driveBaseRadius,
        replanningConfig,
        0.02);
  }

  /**
   * Create a new holonomic path follower config
   *
   * @param maxModuleSpeed Max speed of an individual drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
   *     distance from the center of the robot to the furthest module. For mecanum, this is the
   *     drive base width / 2
   * @param replanningConfig Path replanning configuration
   * @param period Control loop period in seconds (Default = 0.02)
   */
  public HolonomicPathFollowerConfig(
      double maxModuleSpeed,
      double driveBaseRadius,
      ReplanningConfig replanningConfig,
      double period) {
    this(
        new PIDConstants(5.0, 0.0, 0.0),
        new PIDConstants(5.0, 0.0, 0.0),
        maxModuleSpeed,
        driveBaseRadius,
        replanningConfig,
        period);
  }

  /**
   * Create a new holonomic path follower config
   *
   * @param maxModuleSpeed Max speed of an individual drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
   *     distance from the center of the robot to the furthest module. For mecanum, this is the
   *     drive base width / 2
   * @param replanningConfig Path replanning configuration
   */
  public HolonomicPathFollowerConfig(
      double maxModuleSpeed, double driveBaseRadius, ReplanningConfig replanningConfig) {
    this(maxModuleSpeed, driveBaseRadius, replanningConfig, 0.02);
  }
}
