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

  final num nmPerAmp;

  const MotorTorqueCurve(this.nmPerAmp, super._map);

  static MotorTorqueCurve fromString(String curveName) {
    return switch (curveName) {
      'KRAKEN_40A' => kraken40A,
      'KRAKEN_60A' => kraken60A,
      'KRAKEN_80A' => kraken80A,
      'KRAKEN_FOC_40A' => krakenFOC40A,
      'KRAKEN_FOC_60A' => krakenFOC60A,
      'KRAKEN_FOC_80A' => krakenFOC80A,
      _ => kraken60A,
    };
  }

  @override
  String toString() {
    return 'TorqueCurve($map)';
  }
}
