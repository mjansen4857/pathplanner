import 'dart:math';

class GeometryUtil {
  static num numLerp(num startVal, num endVal, num t) {
    return startVal + (endVal - startVal) * t;
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
}
