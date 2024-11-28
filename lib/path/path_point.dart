import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

class PathPoint {
  final Translation2d position;
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
