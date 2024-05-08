import 'package:pathplanner/util/wpimath/interpolating_map.dart';

class MotorTorqueCurve extends InterpolatingMap {
  static const MotorTorqueCurve kraken60A = MotorTorqueCurve(0.0194, {
    0: 1.133,
    5020: 1.133,
    6000: 0.0,
  });
  static const MotorTorqueCurve krakenFOC60A = MotorTorqueCurve(0.0194, {
    0: 1.135,
    5080: 1.135,
    5800: 0.0,
  });

  final num nmPerAmp;

  const MotorTorqueCurve(this.nmPerAmp, super._map);

  static MotorTorqueCurve fromString(String curveName) {
    return switch (curveName) {
      'KRAKEN_60A' => kraken60A,
      'KRAKEN_FOC_60A' => krakenFOC60A,
      _ => kraken60A,
    };
  }

  @override
  String toString() {
    return 'TorqueCurve($map)';
  }
}
