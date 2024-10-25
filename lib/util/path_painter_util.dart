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
      Offset pos =
          PathPainterUtil.pointToPixelOffset(m.translation, scale, fieldImage);

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
      Pose2d pose,
      FieldImage fieldImage,
      Size robotSize,
      double scale,
      Canvas canvas,
      Color color,
      Color outlineColor,
      {bool showDetails = false}) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    Offset center =
        PathPainterUtil.pointToPixelOffset(pose.translation, scale, fieldImage);

    double width =
        PathPainterUtil.metersToPixels(robotSize.width, scale, fieldImage);
    double length =
        PathPainterUtil.metersToPixels(robotSize.height, scale, fieldImage);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pose.rotation.radians.toDouble());
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: length, height: width),
            const Radius.circular(5)),
        paint);

    Offset frontMiddle = center + Offset(length / 2, 0);

    // Draw the dot
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    paint.color = outlineColor;
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);

    canvas.restore();

    if (showDetails) {
      String angleText = '${pose.rotation.degrees.toStringAsFixed(1)}°';
      String coordText =
          '(${pose.x.toStringAsFixed(2)}, ${pose.y.toStringAsFixed(2)})';
      String displayText = '$angleText\n$coordText';

      double textSize = min(width, length) * 0.175;

      TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: displayText,
          style: TextStyle(
            fontSize: textSize,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      textPainter.layout();

      Offset textPosition = center + Offset(-length * 0.4, -width * 0.2);

      canvas.save();

      canvas.translate(textPosition.dx, textPosition.dy);

      final bgRect = Rect.fromCenter(
        center: Offset(textPainter.width / 2, textPainter.height / 2),
        width: textPainter.width + 8,
        height: textPainter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
        Paint()..color = Colors.black.withOpacity(0.6),
      );

      TextPainter outlinePainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: displayText,
          style: TextStyle(
            fontSize: textSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      outlinePainter.layout();
      outlinePainter.paint(canvas, Offset.zero);

      textPainter.paint(canvas, Offset.zero);

      canvas.restore();
    }
  }

  static void paintMarker(
      Canvas canvas, Offset location, Color color, Color strokeColor) {
    const IconData markerIcon = Icons.location_on_rounded;

    TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(markerIcon.codePoint),
        style: TextStyle(
          fontSize: 35, // Set the font size to 35
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
          fontSize: 35, // Set the font size to 35
          fontFamily: markerIcon.fontFamily,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = strokeColor,
        ),
      ),
    );

    textPainter.layout();
    textStrokePainter.layout();

    textPainter.paint(
        canvas, location - const Offset(17.5, 27.5)); // Adjust the offset
    textStrokePainter.paint(
        canvas, location - const Offset(17.5, 27.5)); // Adjust the offset
  }

  static Offset pointToPixelOffset(
      Translation2d point, double scale, FieldImage fieldImage) {
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
