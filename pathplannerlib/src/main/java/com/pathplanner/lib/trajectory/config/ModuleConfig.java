package com.pathplanner.lib.trajectory.config;

import com.pathplanner.lib.trajectory.MotorTorqueCurve;

public record ModuleConfig(
    double wheelRadiusMeters,
    double driveGearing,
    double maxDriveVelocityRPM,
    double wheelCOF,
    MotorTorqueCurve driveMotorTorqueCurve) {
  public double rpmToMps() {
    return ((1.0 / 60.0) / driveGearing) * (2.0 * Math.PI * wheelRadiusMeters);
  }

  public double maxDriveVelocityMPS() {
    return maxDriveVelocityRPM * rpmToMps();
  }
}
