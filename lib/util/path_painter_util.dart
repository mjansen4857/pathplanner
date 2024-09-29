import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';

class PathPainterUtil {
  static void paintRobotModules(List<Pose2d> modulePoses, FieldImage fieldImage,
      double scale, Canvas canvas, Color color) {
    var paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..strokeWidth = 2;

    for (Pose2d m in modulePoses) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          m.translation.asPoint(), scale, fieldImage);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(-m.rotation.radians.toDouble());
      canvas.translate(-pos.dx, -pos.dy);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: pos,
                  width: PathPainterUtil.uiPointSizeToPixels(
                      25, scale, fieldImage),
                  height: PathPainterUtil.uiPointSizeToPixels(
                      12, scale, fieldImage)),
              const Radius.circular(1.0)),
          paint);
      canvas.restore();
    }
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

    double width =
        PathPainterUtil.metersToPixels(robotSize.width, scale, fieldImage);
    double length =
        PathPainterUtil.metersToPixels(robotSize.height, scale, fieldImage);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle.toDouble());
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: length, height: width),
            const Radius.circular(5)),
        paint);
    paint.style = PaintingStyle.fill;
    Offset frontMiddle = center + Offset(length / 2, 0);
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    paint.color = Colors.black;
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
    canvas.restore();
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
