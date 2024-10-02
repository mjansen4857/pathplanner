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
      : this(12, 2.42, 133, 2.7, Units.rpmToRadsPerSec(5310), numMotors);

  DCMotor.getNEO(int numMotors)
      : this(12, 2.6, 105, 1.8, Units.rpmToRadsPerSec(5676), numMotors);

  DCMotor.getMiniCIM(int numMotors)
      : this(12, 1.41, 89, 3, Units.rpmToRadsPerSec(5840), numMotors);

  DCMotor.getFalcon500(int numMotors)
      : this(12, 4.69, 257, 1.5, Units.rpmToRadsPerSec(6380), numMotors);

  DCMotor.getFalcon500FOC(int numMotors)
      : this(12, 5.84, 304, 1.5, Units.rpmToRadsPerSec(6080), numMotors);

  DCMotor.getKrakenX60(int numMotors)
      : this(12, 7.09, 366, 2, Units.rpmToRadsPerSec(6000), numMotors);

  DCMotor.getKrakenX60FOC(int numMotors)
      : this(12, 9.37, 483, 2, Units.rpmToRadsPerSec(5800), numMotors);

  DCMotor.getNeoVortex(int numMotors)
      : this(12, 3.6, 211, 3.6, Units.rpmToRadsPerSec(6784), numMotors);

  num getCurrent(num speedRadPerSec, num voltage) {
    return -1.0 / kVRadPerSecPerVolt / rOhms * speedRadPerSec +
        1.0 / rOhms * voltage;
  }

  num getTorque(num currentAmps) {
    return currentAmps * kTNMPerAmp;
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

  factory DCMotor.fromString(String str, int numMotors) {
    return switch (str) {
      'krakenX60' => DCMotor.getKrakenX60(numMotors),
      'krakenX60FOC' => DCMotor.getKrakenX60FOC(numMotors),
      'falcon500' => DCMotor.getFalcon500(numMotors),
      'falcon500FOC' => DCMotor.getFalcon500FOC(numMotors),
      'vortex' => DCMotor.getNeoVortex(numMotors),
      'NEO' => DCMotor.getNEO(numMotors),
      'CIM' => DCMotor.getCIM(numMotors),
      'miniCIM' => DCMotor.getMiniCIM(numMotors),
      _ => DCMotor.getKrakenX60(numMotors),
    };
  }
}
