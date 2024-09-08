import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/wpimath/interpolating_map.dart';

void main() {
  group('InterpolatingMap', () {
    test('get', () {
      var map = const InterpolatingMap({1: 2, 3: 4});
      expect(map.get(1), equals(2));
      expect(map.get(3), equals(4));
    });

    test('get with interpolation', () {
      var map = const InterpolatingMap({1: 2, 3: 4});
      expect(map.get(2), equals(3)); // Interpolated value between 2 and 4
    });

    test('get with extrapolation', () {
      var map = const InterpolatingMap({1: 2, 3: 4});
      expect(map.get(0), equals(2)); // Extrapolated value at the floor key
      expect(map.get(4), equals(4)); // Extrapolated value at the ceiling key
    });

    test('get with empty map', () {
      var map = const InterpolatingMap({});
      expect(map.get(2), equals(0)); // Returns 0 when the map is empty
    });
  });
}
