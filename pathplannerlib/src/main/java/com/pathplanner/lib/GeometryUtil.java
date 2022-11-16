package com.pathplanner.lib;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;

public class GeometryUtil {
  static double doubleLerp(double startVal, double endVal, double t) {
    return startVal + (endVal - startVal) * t;
  }

  static Rotation2d rotationLerp(Rotation2d startVal, Rotation2d endVal, double t) {
    return startVal.plus(endVal.minus(startVal).times(t));
  }

  static Translation2d translationLerp(Translation2d a, Translation2d b, double t) {
    return a.plus((b.minus(a)).times(t));
  }

  static Translation2d quadraticLerp(Translation2d a, Translation2d b, Translation2d c, double t) {
    Translation2d p0 = translationLerp(a, b, t);
    Translation2d p1 = translationLerp(b, c, t);
    return translationLerp(p0, p1, t);
  }

  static Translation2d cubicLerp(
      Translation2d a, Translation2d b, Translation2d c, Translation2d d, double t) {
    Translation2d p0 = quadraticLerp(a, b, c, t);
    Translation2d p1 = quadraticLerp(b, c, d, t);
    return translationLerp(p0, p1, t);
  }

  static Rotation2d cosineInterpolate(Rotation2d y1, Rotation2d y2, double mu) {
    double mu2 = (1 - Math.cos(mu * Math.PI)) / 2;
    return new Rotation2d(y1.getRadians() * (1 - mu2) + y2.getRadians() * mu2);
  }
}
