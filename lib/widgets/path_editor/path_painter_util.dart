import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/widgets/field_image.dart';

class PathPainterUtil {
  static void paintCenterPath(RobotPath path, Canvas canvas, double scale,
      Color color, FieldImage fieldImage) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      Path p = Path();
      Offset p0 =
          pointToPixelOffset(path.waypoints[i].anchorPoint, scale, fieldImage);
      Offset p1 =
          pointToPixelOffset(path.waypoints[i].nextControl!, scale, fieldImage);
      Offset p2 = pointToPixelOffset(
          path.waypoints[i + 1].prevControl!, scale, fieldImage);
      Offset p3 = pointToPixelOffset(
          path.waypoints[i + 1].anchorPoint, scale, fieldImage);
      p.moveTo(p0.dx, p0.dy);
      p.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

      canvas.drawPath(p, paint);
    }
  }

  static void paintDualPaths(RobotPath path, Size robotSize, Canvas canvas,
      double scale, Color color, FieldImage fieldImage) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      Path p = Path();

      double halfWidth = metersToPixels(robotSize.width / 2, scale, fieldImage);

      Offset p0 =
          pointToPixelOffset(path.waypoints[i].anchorPoint, scale, fieldImage);
      Offset p1 =
          pointToPixelOffset(path.waypoints[i].nextControl!, scale, fieldImage);
      Offset p2 = pointToPixelOffset(
          path.waypoints[i + 1].prevControl!, scale, fieldImage);
      Offset p3 = pointToPixelOffset(
          path.waypoints[i + 1].anchorPoint, scale, fieldImage);

      for (double t = 0; t < 1.0; t += 0.01) {
        Offset center = cubicLerp(p0, p1, p2, p3, t);
        Offset centerNext = cubicLerp(p0, p1, p2, p3, t + 0.01);

        double angle =
            atan2(centerNext.dy - center.dy, centerNext.dx - center.dx);

        Offset r =
            center.translate(-(halfWidth * sin(angle)), halfWidth * cos(angle));
        Offset rNext = centerNext.translate(
            -(halfWidth * sin(angle)), halfWidth * cos(angle));

        if (t == 0) {
          p.moveTo(r.dx, r.dy);
        }
        p.lineTo(rNext.dx, rNext.dy);
      }

      for (double t = 0; t < 1.0; t += 0.01) {
        Offset center = cubicLerp(p0, p1, p2, p3, t);
        Offset centerNext = cubicLerp(p0, p1, p2, p3, t + 0.01);

        double angle =
            atan2(centerNext.dy - center.dy, centerNext.dx - center.dx);

        Offset l =
            center.translate(halfWidth * sin(angle), -(halfWidth * cos(angle)));
        Offset lNext = centerNext.translate(
            halfWidth * sin(angle), -(halfWidth * cos(angle)));

        if (t == 0) {
          p.moveTo(l.dx, l.dy);
        }
        p.lineTo(lNext.dx, lNext.dy);
      }

      canvas.drawPath(p, paint);
    }
  }

  static void paintRobotOutline(
      Waypoint waypoint,
      Size robotSize,
      bool holonomicMode,
      Canvas canvas,
      double scale,
      Color color,
      FieldImage fieldImage) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    Offset center = pointToPixelOffset(waypoint.anchorPoint, scale, fieldImage);
    num angle = (holonomicMode)
        ? (-waypoint.holonomicAngle / 180 * pi)
        : -waypoint.getHeadingRadians();
    double halfWidth = metersToPixels(robotSize.width / 2, scale, fieldImage);
    double halfLength = metersToPixels(robotSize.height / 2, scale, fieldImage);

    Offset l = Offset(center.dx + (halfWidth * sin(angle)),
        center.dy - (halfWidth * cos(angle)));
    Offset r = Offset(center.dx - (halfWidth * sin(angle)),
        center.dy + (halfWidth * cos(angle)));

    Offset frontLeft = Offset(
        l.dx + (halfLength * cos(angle)), l.dy + (halfLength * sin(angle)));
    Offset backLeft = Offset(
        l.dx - (halfLength * cos(angle)), l.dy - (halfLength * sin(angle)));
    Offset frontRight = Offset(
        r.dx + (halfLength * cos(angle)), r.dy + (halfLength * sin(angle)));
    Offset backRight = Offset(
        r.dx - (halfLength * cos(angle)), r.dy - (halfLength * sin(angle)));

    canvas.drawLine(backLeft, frontLeft, paint);
    canvas.drawLine(frontLeft, frontRight, paint);
    canvas.drawLine(frontRight, backRight, paint);
    canvas.drawLine(backRight, backLeft, paint);

    if (holonomicMode) {
      Offset frontMiddle = frontLeft + ((frontRight - frontLeft) * 0.5);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
          frontMiddle, metersToPixels(0.075, scale, fieldImage), paint);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1;
      paint.color = Colors.black;
      canvas.drawCircle(
          frontMiddle, metersToPixels(0.075, scale, fieldImage), paint);
    }
  }

  static Offset pointToPixelOffset(
      Point point, double scale, FieldImage fieldImage) {
    return Offset(
            (point.x * fieldImage.pixelsPerMeter) + 0,
            fieldImage.defaultSize.height -
                ((point.y * fieldImage.pixelsPerMeter) + 0))
        .scale(scale, scale);
  }

  static double metersToPixels(
      double meters, double scale, FieldImage fieldImage) {
    return meters * fieldImage.pixelsPerMeter * scale;
  }

  static Offset lerp(Offset a, Offset b, double t) {
    return a + ((b - a) * t);
  }

  static Offset quadraticLerp(Offset a, Offset b, Offset c, double t) {
    Offset p0 = lerp(a, b, t);
    Offset p1 = lerp(b, c, t);
    return lerp(p0, p1, t);
  }

  static Offset cubicLerp(Offset a, Offset b, Offset c, Offset d, double t) {
    Offset p0 = quadraticLerp(a, b, c, t);
    Offset p1 = quadraticLerp(b, c, d, t);
    return lerp(p0, p1, t);
  }
}
