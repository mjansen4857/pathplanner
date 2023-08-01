import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/services/simulator/rotation_p_controller.dart';

const num epsilon = 0.01;

void main() {
  test('controller', () {
    RotationPController controller = const RotationPController(kP: 2.0);

    expect(controller.calculate(0, pi / 2, 0.1), closeTo(pi, 0.01));
    expect(controller.calculate(0, -pi / 2, 0.1), closeTo(-pi, 0.01));

    expect(controller.calculate(0, pi + (pi / 2), 0.1), closeTo(-pi, 0.01));
    expect(controller.calculate(0, -pi - (pi / 2), 0.1), closeTo(pi, 0.01));
  });
}
