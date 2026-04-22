import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:vector_math/vector_math.dart';

class BezierUtils {
  static Vector2 getCubicBezierNormal(double t, Waypoint pointA, Waypoint pointB) {
    Vector2 p0 = translationToVector(pointA.anchor);
    Vector2 p1 = translationToVector(pointA.nextControl!);
    Vector2 p2 = translationToVector(pointB.prevControl!);
    Vector2 p3 = translationToVector(pointB.anchor);

    Vector2 tangent = getCubicBezierDerivative(t, p0, p1, p2, p3);
    Vector2 secondDerivative = getCubicBezierSecondDerivative(t, p0, p1, p2, p3);
    return getCubicBezierNormalFromTangent(tangent, secondDerivative);
  }

  static Vector2 getCubicBezierDerivative(double t, Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3) {
    final mt = 1 - t;
    return Vector2(
      3 * (mt * mt * (p1.x - p0.x) + 2 * mt * t * (p2.x - p1.x) + t * t * (p3.x - p2.x)),
      3 * (mt * mt * (p1.y - p0.y) + 2 * mt * t * (p2.y - p1.y) + t * t * (p3.y - p2.y)),
    );
  }

  static Vector2 getCubicBezierSecondDerivative(double t, Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3) {
    final mt = 1 - t;
    return Vector2(
      6 * (mt * (p2.x - 2 * p1.x + p0.x) + t * (p3.x - 2 * p2.x + p1.x)),
      6 * (mt * (p2.y - 2 * p1.y + p0.y) + t * (p3.y - 2 * p2.y + p1.y)),
    );
  }

  static Vector2 getCubicBezierNormalFromTangent(Vector2 tangent, Vector2 secondDerivative) {
    final len = tangent.length;
    if (len == 0) return Vector2(0, 0);

    final curvatureSign = (tangent.x * secondDerivative.y - tangent.y * secondDerivative.x);

    final nx = tangent.y / len;
    final ny = -tangent.x / len;

    final sign = curvatureSign >= 0 ? 1.0 : -1.0;
    return Vector2(nx * sign, ny * sign);
  }

  static double getCubicBezierCurvature(double t, Waypoint pointA, Waypoint pointB) {
    Vector2 p0 = translationToVector(pointA.anchor);
    Vector2 p1 = translationToVector(pointA.nextControl!);
    Vector2 p2 = translationToVector(pointB.prevControl!);
    Vector2 p3 = translationToVector(pointB.anchor);

    Vector2 d1 = getCubicBezierDerivative(t, p0, p1, p2, p3);
    Vector2 d2 = getCubicBezierSecondDerivative(t, p0, p1, p2, p3);

    final cross = (d1.x * d2.y - d1.y * d2.x).abs();
    final speed = d1.length;
    if (speed < 1e-10) return 0;
    return cross / (speed * speed * speed);
  }

  static Translation2d getCubicBezierPointTranslation(double t, Waypoint pointA, Waypoint pointB){
    Vector2 p0 = translationToVector(pointA.anchor);
    Vector2 p1 = translationToVector(pointA.nextControl!);
    Vector2 p2 = translationToVector(pointB.prevControl!);
    Vector2 p3 = translationToVector(pointB.anchor);

    return vectorToTranslation(getCubicBezierPoint(t, p0, p1, p2, p3));
  }

  static Vector2 getCubicBezierPoint(double t, Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3) {
    final mt = 1 - t;
    final mt2 = mt * mt;
    final t2 = t * t;

    return Vector2(
      mt2 * mt * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t2 * t * p3.x,
      mt2 * mt * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t2 * t * p3.y,
    );
  }

  static Vector2 translationToVector(Translation2d translation){
    return Vector2(translation.x.toDouble(), translation.y.toDouble());
  }

  static Translation2d vectorToTranslation(Vector2 vector){
    return Translation2d(vector.x, vector.y);
  }
}
