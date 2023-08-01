import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/services/simulator/rotation_p_controller.dart';

const num epsilon = 0.01;

void main() {
  test('controller', () {
    RotationPController controller = const RotationPController(kP: 2.0);

    expect(controller.calculate(0, 90), closeTo(180, 0.01));
    expect(controller.calculate(0, -90), closeTo(-180, 0.01));

    expect(controller.calculate(0, 180 + 90), closeTo(-180, 0.01));
    expect(controller.calculate(0, -180 - 90), closeTo(180, 0.01));
  });
}
