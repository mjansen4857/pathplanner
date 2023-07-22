import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/path_point.dart';

void main() {
  test('Constructor functions', () {
    PathPoint p = PathPoint(position: const Point(1.0, 2.0));

    expect(p.position, const Point(1.0, 2.0));
  });
}
