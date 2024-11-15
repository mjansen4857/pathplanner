import 'package:flutter/material.dart';
import 'package:pathplanner/robot_features/feature.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

class CircleFeature extends Feature {
  Translation2d center;
  num radius;
  num strokeWidth;
  bool filled;

  CircleFeature({
    this.center = const Translation2d(),
    this.radius = 0.1,
    this.strokeWidth = 0.02,
    this.filled = false,
    required super.name,
  }) : super(type: 'circle');

  CircleFeature.fromDataJson(Map<String, dynamic> dataJson, String name)
      : this(
          center: Translation2d.fromJson(dataJson['center']),
          radius: dataJson['radius'],
          strokeWidth: dataJson['strokeWidth'],
          filled: dataJson['filled'],
          name: name,
        );

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'center': center.toJson(),
      'radius': radius,
      'strokeWidth': strokeWidth,
      'filled': filled,
    };
  }

  @override
  void draw(Canvas canvas, double pixelsPerMeter, Color color) {
    Paint paint = Paint()
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth * pixelsPerMeter
      ..color = color;

    Offset centerPixels =
        Offset(center.x * pixelsPerMeter, -center.y * pixelsPerMeter);
    double radiusPixels = radius * pixelsPerMeter;

    canvas.drawCircle(centerPixels, radiusPixels, paint);
  }

  @override
  int get hashCode => Object.hash(type, center, radius, strokeWidth, filled);

  @override
  bool operator ==(Object other) {
    return other is CircleFeature &&
        other.center == center &&
        other.radius == radius &&
        other.strokeWidth == strokeWidth &&
        other.filled == filled;
  }
}
