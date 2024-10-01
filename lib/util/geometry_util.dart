import 'dart:math';

import 'package:pathplanner/util/wpimath/geometry.dart';

class GeometryUtil {
  static Translation2d quadraticLerp(
      Translation2d a, Translation2d b, Translation2d c, num t) {
    return a.interpolate(b, t).interpolate(b.interpolate(c, t), t);
  }

  static Translation2d cubicLerp(Translation2d a, Translation2d b,
      Translation2d c, Translation2d d, num t) {
    return quadraticLerp(a, b, c, t).interpolate(quadraticLerp(b, c, d, t), t);
  }

  static num calculateRadius(
      Translation2d a, Translation2d b, Translation2d c) {
    Translation2d vba = a - b;
    Translation2d vbc = c - b;
    num crossZ = vba.x * vbc.y - vba.y * vbc.x;
    int sign = crossZ < 0.0 ? 1 : -1;
    num ab = a.getDistance(b);
    num bc = b.getDistance(c);
    num ac = a.getDistance(c);
    num p = (ab + bc + ac) / 2;
    num area = sqrt((p * (p - ab) * (p - bc) * (p - ac)).abs());
    return sign * ab * bc * ac / (4 * area);
  }
}
