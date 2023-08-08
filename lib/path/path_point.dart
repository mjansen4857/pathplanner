import 'dart:math';

import 'package:pathplanner/path/path_constraints.dart';

class PathPoint {
  final Point position;
  final num? holonomicRotation;
  final PathConstraints constraints;
  final num distanceAlongPath;
  num maxV = double.infinity;

  PathPoint({
    required this.position,
    required this.holonomicRotation,
    required this.constraints,
    required this.distanceAlongPath,
  });
}
