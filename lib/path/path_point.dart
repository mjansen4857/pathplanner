import 'dart:math';

import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/rotation_target.dart';

class PathPoint {
  final Point position;
  RotationTarget? rotationTarget;
  final PathConstraints constraints;
  num distanceAlongPath = 0.0;
  num maxV = double.infinity;
  final num waypointPos;

  PathPoint({
    required this.position,
    required this.rotationTarget,
    required this.constraints,
    required this.waypointPos,
  });
}
