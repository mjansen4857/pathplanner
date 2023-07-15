import 'dart:math';

import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/generator/geometry_util.dart';

class PathPlannerPath {
  String name;
  List<Waypoint> waypoints;
  List<PathPoint> pathPoints = [];
  PathConstraints globalConstraints;

  PathPlannerPath({
    required this.waypoints,
    this.name = 'New Path',
  }) : globalConstraints = PathConstraints() {
    generatePathPoints();
  }

  PathPlannerPath.defaultPath({this.name = 'New Path'})
      : waypoints = [],
        globalConstraints = PathConstraints() {
    waypoints.addAll([
      Waypoint(
        anchor: const Point(2.0, 7.0),
        nextControl: const Point(3.0, 6.5),
      ),
      Waypoint(
        prevControl: const Point(4.0, 6.0),
        anchor: const Point(5.0, 5.0),
        nextControl: const Point(6.0, 4.0),
      ),
      Waypoint(
        prevControl: const Point(6.75, 2.5),
        anchor: const Point(7.0, 1.0),
      ),
    ]);

    generatePathPoints();
  }

  void generateAndSavePath() {
    generatePathPoints();
  }

  void generatePathPoints() {
    pathPoints.clear();

    for (int i = 0; i < waypoints.length - 1; i++) {
      for (double t = 0; t < 1.0; t += 0.05) {
        pathPoints.add(PathPoint(
          position: GeometryUtil.cubicLerp(
              waypoints[i].anchor,
              waypoints[i].nextControl!,
              waypoints[i + 1].prevControl!,
              waypoints[i + 1].anchor,
              t),
        ));
      }

      if (i == waypoints.length - 2) {
        pathPoints.add(PathPoint(
          position: waypoints[waypoints.length - 1].anchor,
        ));
      }
    }
  }
}
