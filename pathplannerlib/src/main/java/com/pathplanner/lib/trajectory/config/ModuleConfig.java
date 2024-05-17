package com.pathplanner.lib.trajectory.config;

import com.pathplanner.lib.trajectory.MotorTorqueCurve;

public class ModuleConfig {
  public final double wheelRadiusMeters;
  public final double driveGearing;
  public final double maxDriveVelocityRPM;
  public final double wheelCOF;
  public final MotorTorqueCurve driveMotorTorqueCurve;

  // Pre-calculated values that can be reused for every trajectory generation
  public final double rpmToMps;
  public final double maxDriveVelocityMPS;
  public final double torqueLoss;

  public ModuleConfig(
      double wheelRadiusMeters,
      double driveGearing,
      double maxDriveVelocityRPM,
      double wheelCOF,
      MotorTorqueCurve driveMotorTorqueCurve) {
    this.wheelRadiusMeters = wheelRadiusMeters;
    this.driveGearing = driveGearing;
    this.maxDriveVelocityRPM = maxDriveVelocityRPM;
    this.wheelCOF = wheelCOF;
    this.driveMotorTorqueCurve = driveMotorTorqueCurve;

    this.rpmToMps = ((1.0 / 60.0) / this.driveGearing) * (2.0 * Math.PI * this.wheelRadiusMeters);
    this.maxDriveVelocityMPS = this.maxDriveVelocityRPM * this.rpmToMps;
    this.torqueLoss = this.driveMotorTorqueCurve.get(this.maxDriveVelocityRPM);
  }
}
