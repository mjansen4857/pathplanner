package com.pathplanner.lib.trajectory;

import edu.wpi.first.math.interpolation.InterpolatingDoubleTreeMap;

/** Interpolating tree map representing the torque curve of a motor */
public class MotorTorqueCurve extends InterpolatingDoubleTreeMap {
  /** The type of motor */
  public enum MotorType {
    /** Kraken X60 */
    krakenX60,
    /** Kraken X60 with FOC */
    krakenX60_FOC,
    /** Falcon 500 */
    falcon500,
    /** Falcon 500 with FOC */
    falcon500_FOC,
    /** NEO Vortex */
    neoVortex,
    /** NEO */
    neo,
    /** CIM */
    cim,
    /** Mini CIM */
    miniCim,
  }

  /** The current limit of the motor */
  public enum CurrentLimit {
    /** 40 Amp limit */
    k40A,
    /** 60 Amp Limit */
    k60A,
    /** 80 Amp limit */
    k80A,
  }

  private final double nmPerAmp;

  /**
   * Create an empty motor torque curve. This can be used to make a custom curve. Only use this if
   * you know what you're doing
   *
   * @param nmPerAmp Yhe motor's "kT" value, or the conversion from current draw to torque, in
   *     Newton-meters per Amp
   */
  public MotorTorqueCurve(double nmPerAmp) {
    this.nmPerAmp = nmPerAmp;
  }

  /**
   * Create a new motor torque curve
   *
   * @param motorType The type of motor
   * @param currentLimit The current limit of the motor
   */
  public MotorTorqueCurve(MotorType motorType, CurrentLimit currentLimit) {
    switch (motorType) {
      case krakenX60:
        nmPerAmp = 0.0194;
        initKrakenX60(currentLimit);
        break;
      case krakenX60_FOC:
        nmPerAmp = 0.0194;
        initKrakenX60FOC(currentLimit);
        break;
      case falcon500:
        nmPerAmp = 0.0182;
        initFalcon500(currentLimit);
        break;
      case falcon500_FOC:
        nmPerAmp = 0.0192;
        initFalcon500FOC(currentLimit);
        break;
      case neoVortex:
        nmPerAmp = 0.0171;
        initNEOVortex(currentLimit);
        break;
      case neo:
        nmPerAmp = 0.0181;
        initNEO(currentLimit);
        break;
      case cim:
        nmPerAmp = 0.0184;
        initCIM(currentLimit);
        break;
      case miniCim:
        nmPerAmp = 0.0158;
        initMiniCIM(currentLimit);
        break;
      default:
        throw new IllegalArgumentException("Unknown motor type: " + motorType);
    }
  }

  /**
   * Get the motor's "kT" value, or the conversion from current draw to torque
   *
   * @return Newton-meters per Amp
   */
  public double getNmPerAmp() {
    return nmPerAmp;
  }

  private void initKrakenX60(CurrentLimit currentLimit) {
    switch (currentLimit) {
      case k40A:
        put(0.0, 0.746);
        put(5363.0, 0.746);
        put(6000.0, 0.0);
        break;
      case k60A:
        put(0.0, 1.133);
        put(5020.0, 1.133);
        put(6000.0, 0.0);
        break;
      case k80A:
        put(0.0, 1.521);
        put(4699.0, 1.521);
        put(6000.0, 0.0);
        break;
    }
  }

  private void initKrakenX60FOC(CurrentLimit currentLimit) {
    switch (currentLimit) {
      case k40A:
        put(0.0, 0.747);
        put(5333.0, 0.747);
        put(5800.0, 0.0);
        break;
      case k60A:
        put(0.0, 1.135);
        put(5081.0, 1.135);
        put(5800.0, 0.0);
        break;
      case k80A:
        put(0.0, 1.523);
        put(4848.0, 1.523);
        put(5800.0, 0.0);
        break;
    }
  }

  private void initFalcon500(CurrentLimit currentLimit) {
    switch (currentLimit) {
      case k40A:
        put(0.0, 0.703);
        put(5412.0, 0.703);
        put(6380.0, 0.0);
        break;
      case k60A:
        put(0.0, 1.068);
        put(4920.0, 1.068);
        put(6380.0, 0.0);
        break;
      case k80A:
        put(0.0, 1.433);
        put(4407.0, 1.433);
        put(6380.0, 0.0);
        break;
    }
  }

  private void initFalcon500FOC(CurrentLimit currentLimit) {
    switch (currentLimit) {
      case k40A:
        put(0.0, 0.74);
        put(5295.0, 0.74);
        put(6080.0, 0.0);
        break;
      case k60A:
        put(0.0, 1.124);
        put(4888.0, 1.124);
        put(6080.0, 0.0);
        break;
      case k80A:
        put(0.0, 1.508);
        put(4501.0, 1.508);
        put(6080.0, 0.0);
        break;
    }
  }

  private void initNEOVortex(CurrentLimit currentLimit) {
    switch (currentLimit) {
      case k40A:
        put(0.0, 0.621);
        put(5590.0, 0.621);
        put(6784.0, 0.0);
        break;
      case k60A:
        put(0.0, 0.962);
        put(4923.0, 0.962);
        put(6784.0, 0.0);
        break;
      case k80A:
        put(0.0, 1.304);
        put(4279.0, 1.304);
        put(6784.0, 0.0);
        break;
    }
  }

  private void initNEO(CurrentLimit currentLimit) {
    switch (currentLimit) {
      case k40A:
        put(0.0, 0.686);
        put(3773.0, 0.686);
        put(5330.0, 0.0);
        break;
      case k60A:
        put(0.0, 1.054);
        put(2939.0, 1.054);
        put(5330.0, 0.0);
        break;
      case k80A:
        put(0.0, 1.422);
        put(2104.0, 1.422);
        put(5330.0, 0.0);
        break;
    }
  }

  private void initCIM(CurrentLimit currentLimit) {
    switch (currentLimit) {
      case k40A:
        put(0.0, 0.586);
        put(3324.0, 0.586);
        put(5840.0, 0.0);
        break;
      case k60A:
        put(0.0, 0.903);
        put(1954.0, 0.903);
        put(5840.0, 0.0);
        break;
      case k80A:
        put(0.0, 1.22);
        put(604.0, 1.22);
        put(5840.0, 0.0);
        break;
    }
  }

  private void initMiniCIM(CurrentLimit currentLimit) {
    switch (currentLimit) {
      case k40A:
        put(0.0, 0.701);
        put(4620.0, 0.701);
        put(5880.0, 0.0);
        break;
      case k60A:
        put(0.0, 1.064);
        put(3948.0, 1.064);
        put(5880.0, 0.0);
        break;
      case k80A:
        put(0.0, 1.426);
        put(3297.0, 1.426);
        put(5880.0, 0.0);
        break;
    }
  }
}
