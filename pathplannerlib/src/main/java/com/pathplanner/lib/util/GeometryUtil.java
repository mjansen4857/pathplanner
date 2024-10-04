package com.pathplanner.lib.util;

import edu.wpi.first.math.geometry.Translation2d;

/** Utility class for various geometry functions used during generation */
public class GeometryUtil {
  /**
   * Quadratic interpolation between Translation2ds
   *
   * @param a Position 1
   * @param b Position 2
   * @param c Position 3
   * @param t Interpolation factor (0.0-1.0)
   * @return Interpolated value
   */
  public static Translation2d quadraticLerp(
      Translation2d a, Translation2d b, Translation2d c, double t) {
    Translation2d p0 = a.interpolate(b, t);
    Translation2d p1 = b.interpolate(c, t);
    return p0.interpolate(p1, t);
  }

  /**
   * Cubic interpolation between Translation2ds
   *
   * @param a Position 1
   * @param b Position 2
   * @param c Position 3
   * @param d Position 4
   * @param t Interpolation factor (0.0-1.0)
   * @return Interpolated value
   */
  public static Translation2d cubicLerp(
      Translation2d a, Translation2d b, Translation2d c, Translation2d d, double t) {
    Translation2d p0 = quadraticLerp(a, b, c, t);
    Translation2d p1 = quadraticLerp(b, c, d, t);
    return p0.interpolate(p1, t);
  }

  /**
   * Calculate the curve radius given 3 points on the curve
   *
   * @param a Point A
   * @param b Point B
   * @param c Point C
   * @return Curve radius
   */
  public static double calculateRadius(Translation2d a, Translation2d b, Translation2d c) {
    Translation2d vba = a.minus(b);
    Translation2d vbc = c.minus(b);
    double cross_z = (vba.getX() * vbc.getY()) - (vba.getY() * vbc.getX());
    int sign = (cross_z < 0) ? 1 : -1;

    double ab = a.getDistance(b);
    double bc = b.getDistance(c);
    double ac = a.getDistance(c);

    double p = (ab + bc + ac) / 2;
    double area = Math.sqrt(Math.abs(p * (p - ab) * (p - bc) * (p - ac)));
    return sign * (ab * bc * ac) / (4 * area);
  }
}
