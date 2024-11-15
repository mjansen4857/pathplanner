import 'package:flutter/material.dart';
import 'package:pathplanner/robot_features/feature.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

class LineFeature extends Feature {
  Translation2d start;
  Translation2d end;
  num strokeWidth;

  LineFeature({
    this.start = const Translation2d(),
    this.end = const Translation2d(0.2, 0.0),
    this.strokeWidth = 0.02,
    required super.name,
  }) : super(type: 'line');

  LineFeature.fromDataJson(Map<String, dynamic> dataJson, String name)
      : this(
          start: Translation2d.fromJson(dataJson['start']),
          end: Translation2d.fromJson(dataJson['end']),
          strokeWidth: dataJson['strokeWidth'],
          name: name,
        );

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'start': start.toJson(),
      'end': end.toJson(),
      'strokeWidth': strokeWidth,
    };
  }

  @override
  void draw(Canvas canvas, double pixelsPerMeter, Color color) {
    Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * pixelsPerMeter
      ..color = color;

    Offset startPixels =
        Offset(start.x * pixelsPerMeter, -start.y * pixelsPerMeter);
    Offset endPixels = Offset(end.x * pixelsPerMeter, -end.y * pixelsPerMeter);

    canvas.drawLine(startPixels, endPixels, paint);
  }

  @override
  int get hashCode => Object.hash(type, start, end, strokeWidth);

  @override
  bool operator ==(Object other) {
    return other is LineFeature &&
        other.start == start &&
        other.end == end &&
        other.strokeWidth == strokeWidth;
  }
}
