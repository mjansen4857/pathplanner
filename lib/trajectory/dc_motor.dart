import 'package:pathplanner/util/wpimath/units.dart';

class DCMotor {
  final num nominalVoltageVolts;
  final num stallTorqueNM;
  final num stallCurrentAmps;
  final num freeCurrentAmps;
  final num freeSpeedRadPerSec;
  final num rOhms;
  late final num kVRadPerSecPerVolt;
  final num kTNMPerAmp;

  DCMotor(
    this.nominalVoltageVolts,
    num stallTorqueNM,
    num stallCurrentAmps,
    num freeCurrentAmps,
    this.freeSpeedRadPerSec,
    int numMotors,
  )   : stallTorqueNM = stallTorqueNM * numMotors,
        stallCurrentAmps = stallCurrentAmps * numMotors,
        freeCurrentAmps = freeCurrentAmps * numMotors,
        rOhms = nominalVoltageVolts / stallCurrentAmps,
        kTNMPerAmp = stallTorqueNM / stallCurrentAmps {
    kVRadPerSecPerVolt =
        freeSpeedRadPerSec / (nominalVoltageVolts - rOhms * freeCurrentAmps);
  }

  DCMotor.getCIM(int numMotors)
      : this(12, 2.42, 133, 2.7,
            Units.rotationsPerMinuteToRadiansPerSecond(5310), numMotors);

  DCMotor.getNEO(int numMotors)
      : this(12, 2.6, 105, 1.8,
            Units.rotationsPerMinuteToRadiansPerSecond(5676), numMotors);

  DCMotor.getMiniCIM(int numMotors)
      : this(12, 1.41, 89, 3, Units.rotationsPerMinuteToRadiansPerSecond(5310),
            numMotors);

  DCMotor.getFalcon500(int numMotors)
      : this(12, 4.69, 257, 1.5,
            Units.rotationsPerMinuteToRadiansPerSecond(6380), numMotors);

  DCMotor.getFalcon500FOC(int numMotors)
      : this(12, 5.84, 304, 1.5,
            Units.rotationsPerMinuteToRadiansPerSecond(6080), numMotors);

  DCMotor.getKrakenX60(int numMotors)
      : this(12, 7.09, 366, 2, Units.rotationsPerMinuteToRadiansPerSecond(6000),
            numMotors);

  DCMotor.getKrakenX60FOC(int numMotors)
      : this(12, 9.37, 483, 2, Units.rotationsPerMinuteToRadiansPerSecond(5800),
            numMotors);

  DCMotor.getNeoVortex(int numMotors)
      : this(12, 3.6, 211, 3.6,
            Units.rotationsPerMinuteToRadiansPerSecond(6784), numMotors);

  num getCurrent(num speedRadPerSec, num voltage) {
    return -1.0 / kVRadPerSecPerVolt / rOhms * speedRadPerSec +
        1.0 / rOhms * voltage;
  }

  num getTorque(num currentAmps) {
    return currentAmps * kTNMPerAmp;
  }

  num getVoltage(num torqueNM, num speedRadPerSec) {
    return 1.0 / kVRadPerSecPerVolt * speedRadPerSec +
        1.0 / kTNMPerAmp * rOhms * torqueNM;
  }

  num getSpeed(num torqueNM, num voltage) {
    return voltage * kVRadPerSecPerVolt -
        1.0 / kTNMPerAmp * torqueNM * rOhms * kVRadPerSecPerVolt;
  }

  DCMotor withReduction(num gearboxReduction) {
    return DCMotor(
        nominalVoltageVolts,
        stallTorqueNM * gearboxReduction,
        stallCurrentAmps,
        freeCurrentAmps,
        freeSpeedRadPerSec / gearboxReduction,
        1);
  }
}
