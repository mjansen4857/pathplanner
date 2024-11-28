import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/wpimath/units.dart';

const num epsilon = 0.001;

void main() {
  test('rpmToRadsPerSec', () {
    expect(Units.rpmToRadsPerSec(50), closeTo(5.236, epsilon));
    expect(Units.rpmToRadsPerSec(200), closeTo(20.944, epsilon));
    expect(Units.rpmToRadsPerSec(-50), closeTo(-5.236, epsilon));
  });

  test('radiansToDegrees', () {
    expect(Units.radiansToDegrees(0), closeTo(0, epsilon));
    expect(Units.radiansToDegrees(pi), closeTo(180, epsilon));
    expect(Units.radiansToDegrees(-pi), closeTo(-180, epsilon));
  });

  test('degreesToRadians', () {
    expect(Units.degreesToRadians(0), closeTo(0, epsilon));
    expect(Units.degreesToRadians(180), closeTo(pi, epsilon));
    expect(Units.degreesToRadians(-180), closeTo(-pi, epsilon));
  });
}
