import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/field_image.dart';

class PathPainterUtil {
  static Future<void> paintRobotOutline(
      Point position,
      num rotationDegrees,
      FieldImage fieldImage,
      Size robotSize,
      double scale,
      Canvas canvas,
      Color color,
      {IconData? robotIcon,
      bool hasArrow = false,
      bool showDetails = false}) async {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    Offset center =
        PathPainterUtil.pointToPixelOffset(position, scale, fieldImage);
    double angle = (-rotationDegrees / 180 * pi).toDouble();
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

    if (robotIcon != null) {
      TextPainter iconPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(robotIcon.codePoint),
          style: TextStyle(
            fontSize: 28,
            color: color,
            fontFamily: robotIcon.fontFamily,
          ),
        ),
      );
      iconPainter.layout();

      // Position the icon at the center of the robot
      Offset iconCenter = center;
      iconPainter.paint(canvas,
          iconCenter - Offset(iconPainter.width / 2, iconPainter.height / 2));
    }

    Offset frontMiddle = frontLeft + ((frontRight - frontLeft) * 0.5);

    if (hasArrow) {
      canvas.save();

      canvas.translate(frontMiddle.dx, frontMiddle.dy);
      canvas.rotate(angle);
      canvas.translate(7, 0);

      // Draw an arrow icon
      const IconData arrowIcon = Icons.arrow_forward_rounded;
      TextPainter arrowPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(arrowIcon.codePoint),
          style: TextStyle(
            fontSize: 23,
            color: color,
            fontFamily: arrowIcon.fontFamily,
          ),
        ),
      );
      arrowPainter.layout();

      arrowPainter.paint(
          canvas, Offset(-arrowPainter.width / 2, -arrowPainter.height / 2));

      canvas.restore();
    } else {
      // Draw the original dot if hasArrow is false
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(frontMiddle,
          PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1;
      paint.color = Colors.black;
      canvas.drawCircle(frontMiddle,
          PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
    }

    if (showDetails) {
      String angleText = '${rotationDegrees.toStringAsFixed(1)}°';
      String coordText =
          '(${position.x.toStringAsFixed(2)}, ${position.y.toStringAsFixed(2)})';
      String displayText = '$angleText\n$coordText';

      // Calculate text size based on robot size
      double textSize = min(halfWidth, halfLength) * 0.35;

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

      Offset textPosition = Offset(
          backLeft.dx + (frontLeft.dx - backLeft.dx) * 0.2,
          backLeft.dy + (frontLeft.dy - backLeft.dy) * 0.3);

      canvas.save();

      canvas.translate(textPosition.dx, textPosition.dy);

      // Draw a background for the text
      final bgRect = Rect.fromCenter(
        center: Offset(textPainter.width / 2, textPainter.height / 2),
        width: textPainter.width + 8,
        height: textPainter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
        Paint()..color = Colors.black.withOpacity(0.6),
      );

      // Draw text outline
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
