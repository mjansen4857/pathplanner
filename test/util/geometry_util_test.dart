import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  group('quadraticLerp', () {
    test('(1, 2), (3, 4), (5, 6), t = 0.5', () {
      expect(
          GeometryUtil.quadraticLerp(const Translation2d(1, 2),
              const Translation2d(3, 4), const Translation2d(5, 6), 0.5),
          const Translation2d(3, 4));
    });
  });

  group('cubicLerp', () {
    test('(1, 2), (3, 4), (5, 6), (7, 8), t = 0.5', () {
      expect(
          GeometryUtil.cubicLerp(
              const Translation2d(1, 2),
              const Translation2d(3, 4),
              const Translation2d(5, 6),
              const Translation2d(7, 8),
              0.5),
          const Translation2d(4, 5));
    });
  });
}
