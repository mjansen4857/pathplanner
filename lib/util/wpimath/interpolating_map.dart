import 'package:pathplanner/util/wpimath/math_util.dart';

class InterpolatingMap {
  final Map<num, num> _map;

  const InterpolatingMap(this._map);

  void put(num key, num value) {
    _map[key] = value;
  }

  num get(num key) {
    num? val = _map[key];

    if (val == null) {
      num? ceilingKey;
      num? floorKey;

      for (num k in _map.keys) {
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
        return _map[floorKey]!;
      }

      if (floorKey == null) {
        return _map[ceilingKey]!;
      }

      num floor = _map[floorKey]!;
      num ceiling = _map[ceilingKey]!;

      return MathUtil.interpolate(floor, ceiling,
          MathUtil.inverseInterpolate(floorKey, ceilingKey, key));
    } else {
      return val;
    }
  }
}
