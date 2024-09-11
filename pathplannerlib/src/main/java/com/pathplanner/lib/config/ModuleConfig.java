package com.pathplanner.lib.config;

/** Configuration class describing a robot's drive module */
public class ModuleConfig {
  /** Wheel radius in meters */
  public final double wheelRadiusMeters;
  /** The gear ratio between the drive motor and the wheel. Values > 1 indicate a reduction. */
  public final double driveGearing;
  /** The max RPM that the drive motor can reach while actually driving the robot at full output. */
  public final double maxDriveVelocityRPM;
  /** The coefficient of friction between the drive wheel and the carpet. */
  public final double wheelCOF;
  /** The {@link MotorTorqueCurve} for the drive motor */
  public final MotorTorqueCurve driveMotorTorqueCurve;

  // Pre-calculated values that can be reused for every trajectory generation
  /** Conversion factor for converting RPM to MPS */
  public final double rpmToMps;
  /** Max drive motor velocity in MPS */
  public final double maxDriveVelocityMPS;
  /**
   * The amount of motor torque lost while driving. Calculated by getting the torque of the motor at
   * the motor's max RPM under load.
   */
  public final double torqueLoss;

  /**
   * Configuration of a robot drive module. This can either be a swerve module, or one side of a
   * differential drive train.
   *
   * @param wheelRadiusMeters Radius of the drive wheels, in meters.
   * @param driveGearing The gear ratio between the drive motor and the wheel. Values > 1 indicate a
   *     reduction.
   * @param maxDriveVelocityRPM The max RPM that the drive motor can reach while actually driving
   *     the robot at full output.
   * @param wheelCOF The coefficient of friction between the drive wheel and the carpet. If you are
   *     unsure, just use a placeholder value of 1.0.
   * @param driveMotorTorqueCurve The {@link MotorTorqueCurve} for the drive motor
   */
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
