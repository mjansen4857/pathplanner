import 'dart:math';

import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/generator/geometry_util.dart';

class PathPlannerPath {
  String name;
  List<Waypoint> waypoints;
  List<PathPoint> pathPoints;
  PathConstraints globalConstraints;
  GoalEndState goalEndState;
  List<ConstraintsZone> constraintZones;
  List<RotationTarget> rotationTargets;
  List<EventMarker> eventMarkers;

  // Stuff used for UI
  bool waypointsExpanded = false;
  bool globalConstraintsExpanded = false;
  bool goalEndStateExpanded = false;
  bool rotationTargetsExpanded = false;
  bool eventMarkersExpanded = false;
  bool constraintZonesExpanded = false;

  PathPlannerPath.defaultPath({this.name = 'New Path'})
      : waypoints = [],
        pathPoints = [],
        globalConstraints = PathConstraints(),
        goalEndState = GoalEndState(),
        constraintZones = [],
        rotationTargets = [],
        eventMarkers = [] {
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

  void _addNamedCommandsToSet(Command command) {
    if (command is NamedCommand) {
      if (command.name != null) {
        Command.named.add(command.name!);
        return;
      }
    }

    if (command is CommandGroup) {
      for (Command cmd in command.commands) {
        _addNamedCommandsToSet(cmd);
      }
    }
  }

  void generatePathPoints() {
    // Add all command names in this path to the available names
    for (EventMarker m in eventMarkers) {
      _addNamedCommandsToSet(m.command);
    }

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

  static List<Waypoint> cloneWaypoints(List<Waypoint> waypoints) {
    return [
      for (Waypoint waypoint in waypoints) waypoint.clone(),
    ];
  }

  static List<ConstraintsZone> cloneConstraintZones(
      List<ConstraintsZone> zones) {
    return [
      for (ConstraintsZone zone in zones) zone.clone(),
    ];
  }

  static List<RotationTarget> cloneRotationTargets(
      List<RotationTarget> targets) {
    return [
      for (RotationTarget target in targets) target.clone(),
    ];
  }

  static List<EventMarker> cloneEventMarkers(List<EventMarker> markers) {
    return [
      for (EventMarker marker in markers) marker.clone(),
    ];
  }
}
