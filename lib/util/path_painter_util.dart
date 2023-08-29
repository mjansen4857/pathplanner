import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/field_image.dart';

class PathPainterUtil {
  static void paintRobotOutline(
      Point position,
      num rotationDegrees,
      FieldImage fieldImage,
      Size robotSize,
      double scale,
      Canvas canvas,
      Color color) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    Offset center =
        PathPainterUtil.pointToPixelOffset(position, scale, fieldImage);
    num angle = -rotationDegrees / 180 * pi;
    double halfWidth =
        PathPainterUtil.metersToPixels(robotSize.width / 2, scale, fieldImage);
    double halfLength =
        PathPainterUtil.metersToPixels(robotSize.height / 2, scale, fieldImage);

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

    Offset frontMiddle = frontLeft + ((frontRight - frontLeft) * 0.5);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    paint.color = Colors.black;
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
  }

  static void paintPathPoints(
      PathPlannerPath path,
      FieldImage fieldImage,
      int? selectedZone,
      int? hoveredZone,
      Canvas canvas,
      double scale,
      Color baseColor) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 2;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        path.pathPoints[0].position, scale, fieldImage);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < path.pathPoints.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[i].position, scale, fieldImage);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);

    if (selectedZone != null) {
      paint.color = Colors.orange;
      paint.strokeWidth = 4;
      p.reset();

      int startIdx =
          (path.constraintZones[selectedZone].minWaypointRelativePos /
                  pathResolution)
              .round();
      int endIdx = min(
          (path.constraintZones[selectedZone].maxWaypointRelativePos /
                  pathResolution)
              .round(),
          path.pathPoints.length - 1);
      Offset start = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[startIdx].position, scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (int i = startIdx; i <= endIdx; i++) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.pathPoints[i].position, scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }

      canvas.drawPath(p, paint);
    }
    if (hoveredZone != null && selectedZone != hoveredZone) {
      paint.color = Colors.deepPurpleAccent;
      paint.strokeWidth = 4;
      p.reset();

      int startIdx = (path.constraintZones[hoveredZone].minWaypointRelativePos /
              pathResolution)
          .round();
      int endIdx = min(
          (path.constraintZones[hoveredZone].maxWaypointRelativePos /
                  pathResolution)
              .round(),
          path.pathPoints.length - 1);
      Offset start = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[startIdx].position, scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (int i = startIdx; i <= endIdx; i++) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.pathPoints[i].position, scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }

      canvas.drawPath(p, paint);
    }
  }

  static void paintMarker(Canvas canvas, Offset location, Color color) {
    const IconData markerIcon = Icons.location_on;

    TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(markerIcon.codePoint),
        style: TextStyle(
          fontSize: 40,
          color: color,
          fontFamily: markerIcon.fontFamily,
        ),
      ),
    );

    TextPainter textStrokePainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(markerIcon.codePoint),
        style: TextStyle(
          fontSize: 40,
          fontFamily: markerIcon.fontFamily,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black,
        ),
      ),
    );

    textPainter.layout();
    textStrokePainter.layout();

    textPainter.paint(canvas, location - const Offset(20, 37));
    textStrokePainter.paint(canvas, location - const Offset(20, 37));
  }

  static Offset pointToPixelOffset(
      Point point, double scale, FieldImage fieldImage,
      {bool small = false}) {
    if (small &&
        fieldImage.defaultSizeSmall != null &&
        fieldImage.pixelsPerMeterSmall != null) {
      return Offset(
              (point.x * fieldImage.pixelsPerMeterSmall!) + 0,
              fieldImage.defaultSizeSmall!.height -
                  ((point.y * fieldImage.pixelsPerMeterSmall!) + 0))
          .scale(scale, scale);
    } else {
      return Offset(
              (point.x * fieldImage.pixelsPerMeter) + 0,
              fieldImage.defaultSize.height -
                  ((point.y * fieldImage.pixelsPerMeter) + 0))
          .scale(scale, scale);
    }
  }

  static double metersToPixels(
      double meters, double scale, FieldImage fieldImage) {
    return meters * fieldImage.pixelsPerMeter * scale;
  }

  static double uiPointSizeToPixels(
      double size, double scale, FieldImage fieldImage,
      {bool small = false}) {
    // 3240 = width of field image size is based on
    if (small && fieldImage.defaultSizeSmall != null) {
      return size / 3240 * fieldImage.defaultSizeSmall!.width * scale;
    } else {
      return size / 3240 * fieldImage.defaultSize.width * scale;
    }
  }
}
