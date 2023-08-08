import 'dart:math';

import 'math_util.dart';

class GeometryUtil {
  static num numLerp(num startVal, num endVal, num t) {
    return startVal + (endVal - startVal) * t;
  }

  static num rotationLerp(num startVal, num endVal, num t, num limit) {
    if ((startVal - endVal).abs() > limit) {
      if (startVal < 0) {
        startVal += 2 * limit;
      } else {
        endVal += 2 * limit;
      }
    }
    num lerp = startVal + (endVal - startVal) * t;
    lerp = MathUtil.inputModulus(lerp, -limit, limit);
    return lerp;
  }

  static Point pointLerp(Point startVal, Point endVal, num t) {
    return Point(
      numLerp(startVal.x, endVal.x, t),
      numLerp(startVal.y, endVal.y, t),
    );
  }

  static Point quadraticLerp(Point a, Point b, Point c, num t) {
    return pointLerp(
      pointLerp(a, b, t),
      pointLerp(b, c, t),
      t,
    );
  }

  static Point cubicLerp(Point a, Point b, Point c, Point d, num t) {
    return pointLerp(
      quadraticLerp(a, b, c, t),
      quadraticLerp(b, c, d, t),
      t,
    );
  }

  static num toDegrees(num radians) {
    return radians * 180 / pi;
  }

  static num toRadians(num degrees) {
    return degrees * pi / 180;
  }
}
