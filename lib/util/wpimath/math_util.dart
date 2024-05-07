import 'dart:math';

class MathUtil {
  static num clamp(num value, num low, num high) {
    return max(low, min(value, high));
  }

  static num interpolate(num startValue, num endValue, num t) {
    return startValue + (endValue - startValue) * clamp(t, 0, 1);
  }
}
