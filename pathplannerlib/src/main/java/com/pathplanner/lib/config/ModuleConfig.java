package com.pathplanner.lib.config;

import static edu.wpi.first.units.Units.*;

import edu.wpi.first.math.system.plant.DCMotor;
import edu.wpi.first.units.measure.Current;
import edu.wpi.first.units.measure.Distance;
import edu.wpi.first.units.measure.LinearVelocity;

/** Configuration class describing a robot's drive module */
public class ModuleConfig {
  /** Wheel radius in meters */
  public final double wheelRadiusMeters;
  /** The max RPM that the drive motor can reach while actually driving the robot at full output. */
  public final double maxDriveVelocityMPS;
  /** The coefficient of friction between the drive wheel and the carpet. */
  public final double wheelCOF;
  /** The DCMotor representing the drive gearbox, including gear reduction */
  public final DCMotor driveMotor;
  /** The current limit of the drive motor, in Amps */
  public final double driveCurrentLimit;

  /** Max drive motor velocity in MPS */
  public final double maxDriveVelocityRadPerSec;
  /**
   * The amount of motor torque lost while driving. Calculated by getting the torque of the motor at
   * the motor's max speed under load.
   */
  public final double torqueLoss;

  /**
   * Configuration of a robot drive module. This can either be a swerve module, or one side of a
   * differential drive train.
   *
   * @param wheelRadiusMeters Radius of the drive wheels, in meters.
   * @param maxDriveVelocityMPS The max speed that the drive motor can reach while actually driving
   *     the robot at full output, in M/S.
   * @param wheelCOF The coefficient of friction between the drive wheel and the carpet. If you are
   *     unsure, just use a placeholder value of 1.0.
   * @param driveMotor The DCMotor representing the drive motor gearbox, including gear reduction
   * @param driveCurrentLimit The current limit of the drive motor, in Amps
   * @param numMotors The number of motors per module. For swerve, this is 1. For differential, this
   *     is usually 2.
   */
  public ModuleConfig(
      double wheelRadiusMeters,
      double maxDriveVelocityMPS,
      double wheelCOF,
      DCMotor driveMotor,
      double driveCurrentLimit,
      int numMotors) {
    this.wheelRadiusMeters = wheelRadiusMeters;
    this.maxDriveVelocityMPS = maxDriveVelocityMPS;
    this.wheelCOF = wheelCOF;
    this.driveMotor = driveMotor;
    this.driveCurrentLimit = driveCurrentLimit * numMotors;

    this.maxDriveVelocityRadPerSec = this.maxDriveVelocityMPS / this.wheelRadiusMeters;
    double maxSpeedCurrentDraw = this.driveMotor.getCurrent(this.maxDriveVelocityRadPerSec, 12.0);
    this.torqueLoss =
        Math.max(
            this.driveMotor.getTorque(Math.min(maxSpeedCurrentDraw, this.driveCurrentLimit)), 0.0);
  }

  /**
   * Configuration of a robot drive module. This can either be a swerve module, or one side of a
   * differential drive train.
   *
   * @param wheelRadius Radius of the drive wheels.
   * @param maxDriveVelocity The max speed that the drive motor can reach while actually driving the
   *     robot at full output.
   * @param wheelCOF The coefficient of friction between the drive wheel and the carpet. If you are
   *     unsure, just use a placeholder value of 1.0.
   * @param driveMotor The DCMotor representing the drive motor gearbox, including gear reduction
   * @param driveCurrentLimit The current limit of the drive motor
   * @param numMotors The number of motors per module. For swerve, this is 1. For differential, this
   *     is usually 2.
   */
  public ModuleConfig(
      Distance wheelRadius,
      LinearVelocity maxDriveVelocity,
      double wheelCOF,
      DCMotor driveMotor,
      Current driveCurrentLimit,
      int numMotors) {
    this(
        wheelRadius.in(Meters),
        maxDriveVelocity.in(MetersPerSecond),
        wheelCOF,
        driveMotor,
        driveCurrentLimit.in(Amps),
        numMotors);
  }
}
