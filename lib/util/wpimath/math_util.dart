import 'dart:math';

class MathUtil {
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
}
