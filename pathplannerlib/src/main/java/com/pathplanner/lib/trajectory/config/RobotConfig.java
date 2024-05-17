package com.pathplanner.lib.trajectory.config;

import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.SwerveDriveKinematics;

public class RobotConfig {
  public final double massKG;
  public final double MOI;
  public final ModuleConfig moduleConfig;

  public final Translation2d[] moduleLocations;
  public final SwerveDriveKinematics kinematics;
  public final boolean isHolonomic;

  // Pre-calculated values that can be reused for every trajectory generation
  public final int numModules;
  public final double[] modulePivotDistance;
  public final double wheelFrictionForce;

  /**
   * Create a robot config object for a HOLONOMIC DRIVE robot
   *
   * @param massKG The mass of the robot, including bumpers and battery, in KG
   * @param MOI The moment of inertia of the robot, in KG*M^2
   * @param moduleConfig The drive module config
   * @param swerveModuleLocations Robot-relative locations of each swerve module in meters, these
   *     should be the same locations used to create your kinematics
   * @param kinematics Swerve drive kinematics
   */
  public RobotConfig(
      double massKG,
      double MOI,
      ModuleConfig moduleConfig,
      Translation2d[] swerveModuleLocations,
      SwerveDriveKinematics kinematics) {
    this.massKG = massKG;
    this.MOI = MOI;
    this.moduleConfig = moduleConfig;

    this.moduleLocations = swerveModuleLocations;
    this.kinematics = kinematics;
    this.isHolonomic = true;

    this.numModules = this.moduleLocations.length;
    this.modulePivotDistance = new double[this.numModules];
    for (int i = 0; i < this.numModules; i++) {
      this.modulePivotDistance[i] = this.moduleLocations[i].getNorm();
    }
    this.wheelFrictionForce = this.moduleConfig.wheelCOF * (this.massKG * 9.8);
  }

  /**
   * Create a robot config object for a DIFFERENTIAL DRIVE robot
   *
   * @param massKG The mass of the robot, including bumpers and battery, in KG
   * @param MOI The moment of inertia of the robot, in KG*M^2
   * @param moduleConfig The drive module config
   * @param trackwidthMeters The distance between the left and right side of the drivetrain, in
   *     meters
   */
  public RobotConfig(
      double massKG, double MOI, ModuleConfig moduleConfig, double trackwidthMeters) {
    this.massKG = massKG;
    this.MOI = MOI;
    this.moduleConfig = moduleConfig;

    this.moduleLocations =
        new Translation2d[] {
          new Translation2d(0.0, trackwidthMeters / 2.0),
          new Translation2d(0.0, -trackwidthMeters / 2.0),
        };
    this.kinematics = new SwerveDriveKinematics(moduleLocations);
    this.isHolonomic = false;

    this.numModules = this.moduleLocations.length;
    this.modulePivotDistance = new double[this.numModules];
    for (int i = 0; i < this.numModules; i++) {
      this.modulePivotDistance[i] = this.moduleLocations[i].getNorm();
    }
    this.wheelFrictionForce = this.moduleConfig.wheelCOF * (this.massKG * 9.8);
  }

  public static RobotConfig fromGUISettings() {
    // TODO: load config from the GUI shared settings file
    return null;
  }
}
