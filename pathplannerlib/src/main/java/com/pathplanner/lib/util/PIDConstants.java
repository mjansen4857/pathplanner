package com.pathplanner.lib.util;

/** PID constants used to create PID controllers */
public class PIDConstants {
  /** P */
  public final double kP;
  /** I */
  public final double kI;
  /** D */
  public final double kD;
  /** Integral range */
  public final double iZone;

  /**
   * Create a new PIDConstants object
   *
   * @param kP P
   * @param kI I
   * @param kD D
   * @param iZone Integral range
   */
  public PIDConstants(double kP, double kI, double kD, double iZone) {
    this.kP = kP;
    this.kI = kI;
    this.kD = kD;
    this.iZone = iZone;
  }

  /**
   * Create a new PIDConstants object
   *
   * @param kP P
   * @param kI I
   * @param kD D
   */
  public PIDConstants(double kP, double kI, double kD) {
    this(kP, kI, kD, 1.0);
  }

  /**
   * Create a new PIDConstants object
   *
   * @param kP P
   * @param kD D
   */
  public PIDConstants(double kP, double kD) {
    this(kP, 0, kD);
  }

  /**
   * Create a new PIDConstants object
   *
   * @param kP P
   */
  public PIDConstants(double kP) {
    this(kP, 0, 0);
  }
}
