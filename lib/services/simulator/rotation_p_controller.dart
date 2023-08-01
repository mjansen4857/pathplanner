import 'dart:math';

import 'package:pathplanner/util/math_util.dart';

class RotationPController {
  final num kP;

  const RotationPController({
    this.kP = 0,
  });

  num calculate(num measurement, num setpoint, num elapsedTime) {
    num posError = MathUtil.inputModulus(setpoint - measurement, -pi, pi);

    return kP * posError;
  }
}
