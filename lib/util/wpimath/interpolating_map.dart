import 'package:pathplanner/util/wpimath/math_util.dart';

class InterpolatingMap {
  final Map<num, num> map;

  const InterpolatingMap(this.map);

  num get(num key) {
    num? val = map[key];

    if (val == null) {
      num? ceilingKey;
      num? floorKey;

      for (num k in map.keys) {
        if (k > key && (ceilingKey == null || k < ceilingKey)) {
          ceilingKey = k;
        }

        if (k < key && (floorKey == null || k > floorKey)) {
          floorKey = k;
        }
      }

      if (ceilingKey == null && floorKey == null) {
        // Returning 0 here since dealing with null elsewhere would be annoying
        return 0;
      }

      if (ceilingKey == null) {
        return map[floorKey]!;
      }

      if (floorKey == null) {
        return map[ceilingKey]!;
      }

      num floor = map[floorKey]!;
      num ceiling = map[ceilingKey]!;

      return MathUtil.interpolate(floor, ceiling,
          MathUtil.inverseInterpolate(floorKey, ceilingKey, key));
    } else {
      return val;
    }
  }
}
