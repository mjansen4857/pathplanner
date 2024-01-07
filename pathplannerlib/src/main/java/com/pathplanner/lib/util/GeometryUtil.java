package com.pathplanner.lib.util;

import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;

/** Utility class for various geometry functions used during generation */
public class GeometryUtil {
  private static final double FIELD_LENGTH = 16.54;

  /**
   * Flip a field position to the other side of the field, maintaining a blue alliance origin
   *
   * @param pos The position to flip
   * @return The flipped position
   */
  public static Translation2d flipFieldPosition(Translation2d pos) {
    return new Translation2d(FIELD_LENGTH - pos.getX(), pos.getY());
  }

  /**
   * Flip a field rotation to the other side of the field, maintaining a blue alliance origin
   *
   * @param rotation The rotation to flip
   * @return The flipped rotation
   */
  public static Rotation2d flipFieldRotation(Rotation2d rotation) {
    return new Rotation2d(Math.PI).minus(rotation);
  }

  /**
   * Flip a field pose to the other side of the field, maintaining a blue alliance origin
   *
   * @param pose The pose to flip
   * @return The flipped pose
   */
  public static Pose2d flipFieldPose(Pose2d pose) {
    return new Pose2d(
        flipFieldPosition(pose.getTranslation()), flipFieldRotation(pose.getRotation()));
  }

  /**
   * Interpolate between two doubles
   *
   * @param startVal Start value
   * @param endVal End value
   * @param t Interpolation factor (0.0-1.0)
   * @return Interpolated value
   */
  public static double doubleLerp(double startVal, double endVal, double t) {
    return startVal + (endVal - startVal) * t;
  }

  /**
   * Interpolate between two Rotation2ds
   *
   * @param startVal Start value
   * @param endVal End value
   * @param t Interpolation factor (0.0-1.0)
   * @return Interpolated value
   */
  public static Rotation2d rotationLerp(Rotation2d startVal, Rotation2d endVal, double t) {
    return startVal.plus(endVal.minus(startVal).times(t));
  }

  /**
   * Linear interpolation between Translation2ds
   *
   * @param a Position 1
   * @param b Position 2
   * @param t Interpolation factor (0.0-1.0)
   * @return Interpolated value
   */
  public static Translation2d translationLerp(Translation2d a, Translation2d b, double t) {
    return a.plus((b.minus(a)).times(t));
  }

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
    Translation2d p0 = translationLerp(a, b, t);
    Translation2d p1 = translationLerp(b, c, t);
    return translationLerp(p0, p1, t);
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
    return translationLerp(p0, p1, t);
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
