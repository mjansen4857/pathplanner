import 'package:pathplanner/util/wpimath/interpolating_map.dart';

class MotorTorqueCurve extends InterpolatingMap {
  static const MotorTorqueCurve kraken40A = MotorTorqueCurve(0.0194, {
    0: 0.746,
    5363: 0.746,
    6000: 0.0,
  });
  static const MotorTorqueCurve kraken60A = MotorTorqueCurve(0.0194, {
    0: 1.133,
    5020: 1.133,
    6000: 0.0,
  });
  static const MotorTorqueCurve kraken80A = MotorTorqueCurve(0.0194, {
    0: 1.521,
    4699: 1.521,
    6000: 0.0,
  });
  static const MotorTorqueCurve krakenFOC40A = MotorTorqueCurve(0.0194, {
    0: 0.747,
    5333: 0.747,
    5800: 0.0,
  });
  static const MotorTorqueCurve krakenFOC60A = MotorTorqueCurve(0.0194, {
    0: 1.135,
    5081: 1.135,
    5800: 0.0,
  });
  static const MotorTorqueCurve krakenFOC80A = MotorTorqueCurve(0.0194, {
    0: 1.523,
    4848: 1.523,
    5800: 0.0,
  });
  static const MotorTorqueCurve falcon40A = MotorTorqueCurve(0.0182, {
    0: 0.703,
    5412: 0.703,
    6380: 0.0,
  });
  static const MotorTorqueCurve falcon60A = MotorTorqueCurve(0.0182, {
    0: 1.068,
    4920: 1.068,
    6380: 0.0,
  });
  static const MotorTorqueCurve falcon80A = MotorTorqueCurve(0.0182, {
    0: 1.433,
    4407: 1.433,
    6380: 0.0,
  });
  static const MotorTorqueCurve falconFOC40A = MotorTorqueCurve(0.0192, {
    0: 0.74,
    5295: 0.74,
    6080: 0.0,
  });
  static const MotorTorqueCurve falconFOC60A = MotorTorqueCurve(0.0192, {
    0: 1.124,
    4888: 1.124,
    6080: 0.0,
  });
  static const MotorTorqueCurve falconFOC80A = MotorTorqueCurve(0.0192, {
    0: 1.508,
    4501: 1.508,
    6080: 0.0,
  });
  static const MotorTorqueCurve vortex40A = MotorTorqueCurve(0.0171, {
    0: 0.621,
    5590: 0.621,
    6784: 0.0,
  });
  static const MotorTorqueCurve vortex60A = MotorTorqueCurve(0.0171, {
    0: 0.962,
    4923: 0.962,
    6784: 0.0,
  });
  static const MotorTorqueCurve vortex80A = MotorTorqueCurve(0.0171, {
    0: 1.304,
    4279: 1.304,
    6784: 0.0,
  });
  static const MotorTorqueCurve neo40A = MotorTorqueCurve(0.0181, {
    0: 0.701,
    4620: 0.701,
    5880: 0.0,
  });
  static const MotorTorqueCurve neo60A = MotorTorqueCurve(0.0181, {
    0: 1.064,
    3948: 1.064,
    5880: 0.0,
  });
  static const MotorTorqueCurve neo80A = MotorTorqueCurve(0.0181, {
    0: 1.426,
    3297: 1.426,
    5880: 0.0,
  });
  static const MotorTorqueCurve cim40A = MotorTorqueCurve(0.0184, {
    0: 0.686,
    3773: 0.686,
    5330: 0.0,
  });
  static const MotorTorqueCurve cim60A = MotorTorqueCurve(0.0184, {
    0: 1.054,
    2939: 1.054,
    5330: 0.0,
  });
  static const MotorTorqueCurve cim80A = MotorTorqueCurve(0.0184, {
    0: 1.422,
    2104: 1.422,
    5330: 0.0,
  });
  static const MotorTorqueCurve minicim40A = MotorTorqueCurve(0.0158, {
    0: 0.586,
    3324: 0.586,
    5840: 0.0,
  });
  static const MotorTorqueCurve minicim60A = MotorTorqueCurve(0.0158, {
    0: 0.903,
    1954: 0.903,
    5840: 0.0,
  });
  static const MotorTorqueCurve minicim80A = MotorTorqueCurve(0.0158, {
    0: 1.22,
    604: 1.22,
    5840: 0.0,
  });

  final num nmPerAmp;

  const MotorTorqueCurve(this.nmPerAmp, super._map);

  static MotorTorqueCurve fromString(String curveName) {
    return switch (curveName) {
      'KRAKEN_40A' => kraken40A,
      'KRAKEN_60A' => kraken60A,
      'KRAKEN_80A' => kraken80A,
      'KRAKENFOC_40A' => krakenFOC40A,
      'KRAKENFOC_60A' => krakenFOC60A,
      'KRAKENFOC_80A' => krakenFOC80A,
      'FALCON_40A' => falcon40A,
      'FALCON_60A' => falcon60A,
      'FALCON_80A' => falcon80A,
      'FALCONFOC_40A' => falconFOC40A,
      'FALCONFOC_60A' => falconFOC60A,
      'FALCONFOC_80A' => falconFOC80A,
      'VORTEX_40A' => vortex40A,
      'VORTEX_60A' => vortex60A,
      'VORTEX_80A' => vortex80A,
      'NEO_40A' => neo40A,
      'NEO_60A' => neo60A,
      'NEO_80A' => neo80A,
      'CIM_40A' => cim40A,
      'CIM_60A' => cim60A,
      'CIM_80A' => cim80A,
      'MINICIM_40A' => minicim40A,
      'MINICIM_60A' => minicim60A,
      'MINICIM_80A' => minicim80A,
      _ => kraken60A,
    };
  }
}
