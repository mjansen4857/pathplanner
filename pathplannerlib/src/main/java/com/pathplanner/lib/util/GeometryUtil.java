package com.pathplanner.lib.util;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;

public class GeometryUtil {
  public static double doubleLerp(double startVal, double endVal, double t) {
    return startVal + (endVal - startVal) * t;
  }

  public static Rotation2d rotationLerp(Rotation2d startVal, Rotation2d endVal, double t) {
    return startVal.plus(endVal.minus(startVal).times(t));
  }

  public static Translation2d translationLerp(Translation2d a, Translation2d b, double t) {
    return a.plus((b.minus(a)).times(t));
  }

  public static Translation2d quadraticLerp(
      Translation2d a, Translation2d b, Translation2d c, double t) {
    Translation2d p0 = translationLerp(a, b, t);
    Translation2d p1 = translationLerp(b, c, t);
    return translationLerp(p0, p1, t);
  }

  public static Translation2d cubicLerp(
      Translation2d a, Translation2d b, Translation2d c, Translation2d d, double t) {
    Translation2d p0 = quadraticLerp(a, b, c, t);
    Translation2d p1 = quadraticLerp(b, c, d, t);
    return translationLerp(p0, p1, t);
  }

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
