import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/math_util.dart';

void main() {
  group('inputModulus', () {
    test('in range', () {
      expect(MathUtil.inputModulus(100, 0, 360), 100);
    });

    test('below min', () {
      expect(MathUtil.inputModulus(-40, 0, 360), 320);
    });

    test('above max', () {
      expect(MathUtil.inputModulus(400, 0, 360), 40);
    });

    test('below min multiple', () {
      expect(MathUtil.inputModulus(-320, 0, 100), 80);
    });

    test('above max multiple', () {
      expect(MathUtil.inputModulus(475, 0, 100), 75);
    });
  });
}
