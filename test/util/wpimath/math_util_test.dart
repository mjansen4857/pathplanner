import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';

void main() {
  group('MathUtil', () {
    test('clamp', () {
      expect(MathUtil.clamp(5, 1, 10), equals(5));
      expect(MathUtil.clamp(0, 1, 10), equals(1));
      expect(MathUtil.clamp(15, 1, 10), equals(10));
    });

    test('interpolate', () {
      expect(MathUtil.interpolate(1, 3, 0.5), equals(2));
      expect(MathUtil.interpolate(1, 3, 0), equals(1));
      expect(MathUtil.interpolate(1, 3, 1), equals(3));
    });

    test('inverseInterpolate', () {
      expect(MathUtil.inverseInterpolate(1, 3, 2), equals(0.5));
      expect(MathUtil.inverseInterpolate(1, 3, 1), equals(0));
      expect(MathUtil.inverseInterpolate(1, 3, 3), equals(1));
    });

    test('epsilonEquals', () {
      expect(MathUtil.epsilonEquals(1, 1), isTrue);
      expect(MathUtil.epsilonEquals(1, 1.00000001), isTrue);
      expect(MathUtil.epsilonEquals(1, 1.0000001), isFalse);
    });
  });

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
