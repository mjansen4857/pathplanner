import 'package:pathplanner/util/math_util.dart';

class RotationPController {
  final num kP;

  const RotationPController({
    this.kP = 0,
  });

  num calculate(num measurement, num setpoint) {
    num posError = MathUtil.inputModulus(setpoint - measurement, -180, 180);

    return kP * posError;
  }
}
