import 'dart:ui';

import 'package:pathplanner/robot_features/feature.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

class RoundedRectFeature extends Feature {
  Translation2d center;
  Size size;
  num borderRadius;
  num strokeWidth;
  bool filled;

  RoundedRectFeature({
    this.center = const Translation2d(),
    this.size = const Size(0.2, 0.2),
    this.borderRadius = 0.05,
    this.strokeWidth = 0.02,
    this.filled = false,
    required super.name,
  }) : super(type: 'rounded_rect');

  RoundedRectFeature.fromDataJson(Map<String, dynamic> dataJson, String name)
      : this(
          center: Translation2d.fromJson(dataJson['center']),
          size: Size(dataJson['size']['width'], dataJson['size']['length']),
          borderRadius: dataJson['borderRadius'],
          strokeWidth: dataJson['strokeWidth'],
          filled: dataJson['filled'],
          name: name,
        );

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'center': center.toJson(),
      'size': {
        'width': size.width,
        'length': size.height,
      },
      'borderRadius': borderRadius,
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
    Size sizePixels = size * pixelsPerMeter;
    double borderRadiusPixels = borderRadius * pixelsPerMeter;

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: centerPixels,
                width: sizePixels.height,
                height: sizePixels.width),
            Radius.circular(borderRadiusPixels)),
        paint);
  }

  @override
  int get hashCode =>
      Object.hash(type, center, size, borderRadius, strokeWidth, filled);

  @override
  bool operator ==(Object other) {
    return other is RoundedRectFeature &&
        other.center == center &&
        other.size == size &&
        other.borderRadius == borderRadius &&
        other.strokeWidth == strokeWidth &&
        other.filled == filled;
  }
}
