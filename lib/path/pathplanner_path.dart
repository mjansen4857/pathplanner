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

  void addWaypoint(Point anchorPos) {
    waypoints[waypoints.length - 1].addNextControl();
    waypoints.add(
      Waypoint(
        prevControl:
            (waypoints[waypoints.length - 1].nextControl! + anchorPos) * 0.5,
        anchor: anchorPos,
      ),
    );
  }

  void insertWaypointAfter(int waypointIdx) {
    if (waypointIdx == waypoints.length - 1) {
      return;
    }

    Waypoint before = waypoints[waypointIdx];
    Waypoint after = waypoints[waypointIdx + 1];
    Point anchorPos = GeometryUtil.cubicLerp(before.anchor, before.nextControl!,
        after.prevControl!, after.anchor, 0.5);

    Waypoint toAdd = Waypoint(
      anchor: anchorPos,
      prevControl: (anchorPos + before.nextControl!) * 0.5,
    );
    toAdd.addNextControl();

    waypoints.insert(waypointIdx + 1, toAdd);

    for (RotationTarget t in rotationTargets) {
      t.waypointRelativePos = _adjustInsertedWaypointRelativePos(
          t.waypointRelativePos, waypointIdx + 1);
    }

    for (EventMarker m in eventMarkers) {
      m.waypointRelativePos = _adjustInsertedWaypointRelativePos(
          m.waypointRelativePos, waypointIdx + 1);
    }

    for (ConstraintsZone z in constraintZones) {
      z.minWaypointRelativePos = _adjustInsertedWaypointRelativePos(
          z.minWaypointRelativePos, waypointIdx + 1);
      z.maxWaypointRelativePos = _adjustInsertedWaypointRelativePos(
          z.maxWaypointRelativePos, waypointIdx + 1);
    }
  }

  num _adjustInsertedWaypointRelativePos(num pos, int insertedWaypointIdx) {
    if (pos >= insertedWaypointIdx) {
      return pos + 1.0;
    } else if (pos >= insertedWaypointIdx - 0.5) {
      int segment = pos.floor();
      double segmentPct = pos % 1.0;

      num newPos = (segment + 1) + ((segmentPct - 0.5) * 2.0);
      newPos = (newPos * 20).round() / 20.0;

      return min(waypoints.length - 1, max(0, newPos));
    } else if (pos > insertedWaypointIdx - 1) {
      int segment = pos.floor();
      double segmentPct = pos % 1.0;

      double newPos = segment + (segmentPct * 2.0);
      newPos = (newPos * 20).round() / 20.0;

      return min(waypoints.length - 1, max(0, newPos));
    }

    return pos;
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
