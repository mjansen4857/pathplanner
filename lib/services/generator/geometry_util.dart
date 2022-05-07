import 'dart:math';

import 'package:flutter/widgets.dart';

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

  static Offset offsetLerp(Offset startVal, Offset endVal, num t) {
    return Offset(
      numLerp(startVal.dx, endVal.dx, t).toDouble(),
      numLerp(startVal.dy, endVal.dy, t).toDouble(),
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
}
