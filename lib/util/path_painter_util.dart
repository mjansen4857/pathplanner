import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/field_image.dart';

class PathPainterUtil {
  static void paintRobotModules(
      Point robotPosition,
      num rotation,
      FieldImage fieldImage,
      num wheelbase,
      num trackwidth,
      double scale,
      Canvas canvas,
      Color color) {
    var paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..strokeWidth = 2;

    Offset center =
        PathPainterUtil.pointToPixelOffset(robotPosition, scale, fieldImage);
    num angle = -rotation / 180 * pi;
    double halfWheelbase =
        PathPainterUtil.metersToPixels(wheelbase / 2, scale, fieldImage);
    double halfTrackwidth =
        PathPainterUtil.metersToPixels(trackwidth / 2, scale, fieldImage);

    Offset l = Offset(center.dx + (halfTrackwidth * sin(angle)),
        center.dy - (halfTrackwidth * cos(angle)));
    Offset r = Offset(center.dx - (halfTrackwidth * sin(angle)),
        center.dy + (halfTrackwidth * cos(angle)));

    Offset frontLeft = Offset(l.dx + (halfWheelbase * cos(angle)),
        l.dy + (halfWheelbase * sin(angle)));
    Offset backLeft = Offset(l.dx - (halfWheelbase * cos(angle)),
        l.dy - (halfWheelbase * sin(angle)));
    Offset frontRight = Offset(r.dx + (halfWheelbase * cos(angle)),
        r.dy + (halfWheelbase * sin(angle)));
    Offset backRight = Offset(r.dx - (halfWheelbase * cos(angle)),
        r.dy - (halfWheelbase * sin(angle)));

    canvas.drawCircle(frontLeft,
        PathPainterUtil.uiPointSizeToPixels(8, scale, fieldImage), paint);
    canvas.drawCircle(frontRight,
        PathPainterUtil.uiPointSizeToPixels(8, scale, fieldImage), paint);
    canvas.drawCircle(backLeft,
        PathPainterUtil.uiPointSizeToPixels(8, scale, fieldImage), paint);
    canvas.drawCircle(backRight,
        PathPainterUtil.uiPointSizeToPixels(8, scale, fieldImage), paint);
  }

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

  static double uiPointSizeToPixels(
      double size, double scale, FieldImage fieldImage) {
    // 3240 = width of field image size is based on
    return size / 3240 * fieldImage.defaultSize.width * scale;
  }
}
