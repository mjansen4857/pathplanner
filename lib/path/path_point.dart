import 'dart:math';

import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/rotation_target.dart';

class PathPoint {
  final Point position;
  RotationTarget? rotationTarget;
  final PathConstraints constraints;
  final num distanceAlongPath;
  num maxV = double.infinity;
  num waypointPos = 0.0;

  PathPoint({
    required this.position,
    required this.rotationTarget,
    required this.constraints,
    required this.distanceAlongPath,
  });
}
