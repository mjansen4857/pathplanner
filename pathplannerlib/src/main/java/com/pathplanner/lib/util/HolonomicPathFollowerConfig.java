package com.pathplanner.lib.util;

/** Configuration for the holonomic path following commands */
public class HolonomicPathFollowerConfig {
  public final PIDConstants translationConstants;
  public final PIDConstants rotationConstants;
  public final double maxModuleSpeed;
  public final double driveBaseRadius;
  public final double period;
  public final ReplanningConfig replanningConfig;

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
   * @param period Control loop period in seconds (Default = 0.02)
   * @param replanningConfig Path replanning configuration
   */
  public HolonomicPathFollowerConfig(
      PIDConstants translationConstants,
      PIDConstants rotationConstants,
      double maxModuleSpeed,
      double driveBaseRadius,
      double period,
      ReplanningConfig replanningConfig) {
    this.translationConstants = translationConstants;
    this.rotationConstants = rotationConstants;
    this.maxModuleSpeed = maxModuleSpeed;
    this.driveBaseRadius = driveBaseRadius;
    this.period = period;
    this.replanningConfig = replanningConfig;
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
        0.02,
        replanningConfig);
  }

  /**
   * Create a new holonomic path follower config
   *
   * @param maxModuleSpeed Max speed of an individual drive module in meters/sec
   * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
   *     distance from the center of the robot to the furthest module. For mecanum, this is the
   *     drive base width / 2
   * @param period Control loop period in seconds (Default = 0.02)
   * @param replanningConfig Path replanning configuration
   */
  public HolonomicPathFollowerConfig(
      double maxModuleSpeed,
      double driveBaseRadius,
      double period,
      ReplanningConfig replanningConfig) {
    this(
        new PIDConstants(5.0, 0.0, 0.0),
        new PIDConstants(5.0, 0.0, 0.0),
        maxModuleSpeed,
        driveBaseRadius,
        period,
        replanningConfig);
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
    this(maxModuleSpeed, driveBaseRadius, 0.02, replanningConfig);
  }
}
