import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/services/generator/geometry_util.dart';

void main() {
  group('numLerp', () {
    test('0 to 1, t = 0.5', () {
      expect(GeometryUtil.numLerp(0, 1, 0.5), 0.5);
    });

    test('10 to 20, t = 0.2', () {
      expect(GeometryUtil.numLerp(10, 20, 0.2), 12);
    });

    test('-100 to -120, t = 0.9', () {
      expect(GeometryUtil.numLerp(-100, -120, 0.9), -118);
    });

    test('0 to 1, t = 0.0', () {
      expect(GeometryUtil.numLerp(0, 1, 0.0), 0);
    });

    test('0 to 1, t = 1.0', () {
      expect(GeometryUtil.numLerp(0, 1, 1.0), 1);
    });
  });

  group('pointLerp', () {
    test('(2.3, 7) to (3.5, 2.1), t = 0.2', () {
      expect(
          GeometryUtil.pointLerp(
              const Point(2.3, 7), const Point(3.5, 2.1), 0.2),
          const Point(2.54, 6.02));
    });

    test('(-1.5, 2) to (1.5, -3), t = 0.5', () {
      expect(
          GeometryUtil.pointLerp(
              const Point(-1.5, 2), const Point(1.5, -3), 0.5),
          const Point(0, -0.5));
    });
  });

  group('quadraticLerp', () {
    test('(1, 2), (3, 4), (5, 6), t = 0.5', () {
      expect(
          GeometryUtil.quadraticLerp(
              const Point(1, 2), const Point(3, 4), const Point(5, 6), 0.5),
          const Point(3, 4));
    });
  });

  group('cubicLerp', () {
    test('(1, 2), (3, 4), (5, 6), (7, 8), t = 0.5', () {
      expect(
          GeometryUtil.cubicLerp(const Point(1, 2), const Point(3, 4),
              const Point(5, 6), const Point(7, 8), 0.5),
          const Point(4, 5));
    });
  });

  group('toDegrees', () {
    test('0 radians = 0 degrees', () {
      expect(GeometryUtil.toDegrees(0), 0);
    });

    test('pi radians = 180 degrees', () {
      expect(GeometryUtil.toDegrees(pi), 180);
    });

    test('-pi radians = -180 degrees', () {
      expect(GeometryUtil.toDegrees(-pi), -180);
    });
  });
}
