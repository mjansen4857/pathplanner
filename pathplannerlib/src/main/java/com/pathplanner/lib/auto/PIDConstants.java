package com.pathplanner.lib.auto;

public class PIDConstants {
  public final double kP;
  public final double kI;
  public final double kD;
  public final double period;

  public PIDConstants(double kP, double kI, double kD, double period) {
    this.kP = kP;
    this.kI = kI;
    this.kD = kD;
    this.period = period;
  }

  public PIDConstants(double kP, double kI, double kD) {
    this(kP, kI, kD, 0.02);
  }
}
