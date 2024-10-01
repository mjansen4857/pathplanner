import 'dart:math';

class MathUtil {
  static const _kEpsilon = 1E-8;

  static num clamp(num value, num low, num high) {
    return max(low, min(value, high));
  }

  static num interpolate(num startValue, num endValue, num t) {
    return startValue + (endValue - startValue) * clamp(t, 0, 1);
  }

  static num inverseInterpolate(num startValue, num endValue, num q) {
    num totalRange = endValue - startValue;
    if (totalRange <= 0) {
      return 0;
    }

    num queryToStart = q - startValue;
    if (queryToStart <= 0) {
      return 0;
    }
    return queryToStart / totalRange;
  }

  static bool epsilonEquals(num a, num b) {
    return (a - _kEpsilon <= b) && (a + _kEpsilon >= b);
  }

  static num inputModulus(num input, num minimumInput, num maximumInput) {
    num modulus = maximumInput - minimumInput;

    // Wrap input if it's above the maximum input
    int numMax = (input - minimumInput) ~/ modulus;
    input -= numMax * modulus;

    // Wrap input if it's below the minimum input
    int numMin = (input - maximumInput) ~/ modulus;
    input -= numMin * modulus;

    return input;
  }
}
