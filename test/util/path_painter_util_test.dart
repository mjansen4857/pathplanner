import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';

void main() {
  final fieldImage = FieldImage.official(OfficialField.rebuilt);

  test('field origin maps to the center of the image', () {
    final center = PathPainterUtil.pointToPixelOffset(
      const Translation2d(),
      1,
      fieldImage,
    );

    expect(center.dx, fieldImage.defaultSize.width / 2);
    expect(center.dy, fieldImage.defaultSize.height / 2);
  });

  test('pixel and meter conversions preserve the existing axis directions', () {
    const point = Translation2d(1.25, -0.75);
    const scale = 0.4;
    final pixels = PathPainterUtil.pointToPixelOffset(point, scale, fieldImage);

    expect(
      PathPainterUtil.xPixelsToMeters(pixels.dx, scale, fieldImage),
      closeTo(point.x.toDouble(), 1e-9),
    );
    expect(
      PathPainterUtil.yPixelsToMeters(pixels.dy, scale, fieldImage),
      closeTo(point.y.toDouble(), 1e-9),
    );
    expect(
      PathPainterUtil.pointToPixelOffset(
        const Translation2d(1, 0),
        scale,
        fieldImage,
      ).dx,
      greaterThan(
        PathPainterUtil.pointToPixelOffset(
          const Translation2d(),
          scale,
          fieldImage,
        ).dx,
      ),
    );
    expect(
      PathPainterUtil.pointToPixelOffset(
        const Translation2d(0, 1),
        scale,
        fieldImage,
      ).dy,
      lessThan(
        PathPainterUtil.pointToPixelOffset(
          const Translation2d(),
          scale,
          fieldImage,
        ).dy,
      ),
    );
  });
}
