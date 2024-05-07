import 'package:pathplanner/util/wpimath/interpolating_map.dart';

class MotorTorqueCurve extends InterpolatingMap {
  static const MotorTorqueCurve kraken60A = MotorTorqueCurve(0.0194, {
    0: 1.133,
    5020: 1.133,
    6000: 0.0,
  });

  final num nmPerAmp;

  const MotorTorqueCurve(this.nmPerAmp, super._map);
}
