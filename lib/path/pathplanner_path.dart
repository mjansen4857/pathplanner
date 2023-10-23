import 'dart:convert';
import 'dart:math';

import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/preview_starting_state.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/util/geometry_util.dart';

const double pathResolution = 0.025;

class PathPlannerPath {
  String name;
  List<Waypoint> waypoints;
  List<PathPoint> pathPoints;
  PathConstraints globalConstraints;
  GoalEndState goalEndState;
  List<ConstraintsZone> constraintZones;
  List<RotationTarget> rotationTargets;
  List<EventMarker> eventMarkers;
  bool reversed;
  PreviewStartingState? previewStartingState;
  String? folder;

  FileSystem fs;
  String pathDir;

  // Stuff used for UI
  bool waypointsExpanded = false;
  bool globalConstraintsExpanded = false;
  bool goalEndStateExpanded = false;
  bool rotationTargetsExpanded = false;
  bool eventMarkersExpanded = false;
  bool constraintZonesExpanded = false;
  bool previewStartingStateExpanded = false;
  DateTime lastModified = DateTime.now().toUtc();

  PathPlannerPath.defaultPath({
    required this.pathDir,
    required this.fs,
    this.name = 'New Path',
    this.folder,
  })  : waypoints = [],
        pathPoints = [],
        globalConstraints = PathConstraints(),
        goalEndState = GoalEndState(),
        constraintZones = [],
        rotationTargets = [],
        eventMarkers = [],
        reversed = false,
        previewStartingState = null {
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

  PathPlannerPath({
    required this.name,
    required this.waypoints,
    required this.globalConstraints,
    required this.goalEndState,
    required this.constraintZones,
    required this.rotationTargets,
    required this.eventMarkers,
    required this.pathDir,
    required this.fs,
    required this.reversed,
    required this.folder,
    required this.previewStartingState,
  }) : pathPoints = [] {
    generatePathPoints();
  }

  PathPlannerPath.fromJsonV1(
      Map<String, dynamic> json, String name, String pathsDir, FileSystem fs)
      : this(
          pathDir: pathsDir,
          fs: fs,
          name: name,
          waypoints: [
            for (var waypointJson in json['waypoints'])
              Waypoint.fromJson(waypointJson),
          ],
          globalConstraints:
              PathConstraints.fromJson(json['globalConstraints'] ?? {}),
          goalEndState: GoalEndState.fromJson(json['goalEndState'] ?? {}),
          constraintZones: [
            for (var zoneJson in json['constraintZones'] ?? [])
              ConstraintsZone.fromJson(zoneJson),
          ],
          rotationTargets: [
            for (var targetJson in json['rotationTargets'] ?? [])
              RotationTarget.fromJson(targetJson),
          ],
          eventMarkers: [
            for (var markerJson in json['eventMarkers'] ?? [])
              EventMarker.fromJson(markerJson),
          ],
          reversed: json['reversed'] ?? false,
          folder: json['folder'],
          previewStartingState: json['previewStartingState'] == null
              ? null
              : PreviewStartingState.fromJson(json['previewStartingState']),
        );

  void generateAndSavePath() {
    Stopwatch s = Stopwatch()..start();

    generatePathPoints();

    try {
      File pathFile = fs.file(join(pathDir, '$name.path'));
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      pathFile.writeAsString(encoder.convert(this));
      lastModified = DateTime.now().toUtc();
      Log.debug(
          'Saved and generated "$name.path" in ${s.elapsedMilliseconds}ms');
    } catch (ex, stack) {
      Log.error('Failed to save path', ex, stack);
    }
  }

  static Future<List<PathPlannerPath>> loadAllPathsInDir(
      String pathsDir, FileSystem fs) async {
    List<PathPlannerPath> paths = [];

    List<FileSystemEntity> files = fs.directory(pathsDir).listSync();
    for (FileSystemEntity e in files) {
      if (e.path.endsWith('.path')) {
        final file = fs.file(e.path);
        String jsonStr = await file.readAsString();
        try {
          Map<String, dynamic> json = jsonDecode(jsonStr);
          String pathName = basenameWithoutExtension(e.path);

          if (json['version'] == 1.0) {
            PathPlannerPath path =
                PathPlannerPath.fromJsonV1(json, pathName, pathsDir, fs);
            path.lastModified = (await file.lastModified()).toUtc();

            paths.add(path);
          } else {
            Log.error('Unknown path version');
          }
        } catch (ex, stack) {
          Log.error('Failed to load path', ex, stack);
        }
      }
    }
    return paths;
  }

  void deletePath() {
    File pathFile = fs.file(join(pathDir, '$name.path'));

    if (pathFile.existsSync()) {
      pathFile.delete();
    }
  }

  void renamePath(String name) {
    File pathFile = fs.file(join(pathDir, '${this.name}.path'));

    if (pathFile.existsSync()) {
      pathFile.rename(join(pathDir, '$name.path'));
    }
    this.name = name;
    lastModified = DateTime.now().toUtc();
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1.0,
      'waypoints': [
        for (Waypoint w in waypoints) w.toJson(),
      ],
      'rotationTargets': [
        for (RotationTarget t in rotationTargets) t.toJson(),
      ],
      'constraintZones': [
        for (ConstraintsZone z in constraintZones) z.toJson(),
      ],
      'eventMarkers': [
        for (EventMarker m in eventMarkers) m.toJson(),
      ],
      'globalConstraints': globalConstraints.toJson(),
      'goalEndState': goalEndState.toJson(),
      'reversed': reversed,
      'folder': folder,
      'previewStartingState': previewStartingState,
    };
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
    if (waypointIdx >= waypoints.length - 1 || waypointIdx < 0) {
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

  bool hasEmptyNamedCommand() {
    for (EventMarker m in eventMarkers) {
      bool hasEmpty = _hasEmptyNamedCommand(m.command.commands);
      if (hasEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasEmptyNamedCommand(List<Command> commands) {
    for (Command cmd in commands) {
      if (cmd is NamedCommand && cmd.name == null) {
        return true;
      } else if (cmd is CommandGroup) {
        bool hasEmpty = _hasEmptyNamedCommand(cmd.commands);
        if (hasEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  void generatePathPoints() {
    // Add all command names in this path to the available names
    for (EventMarker m in eventMarkers) {
      _addNamedCommandsToSet(m.command);
    }

    pathPoints.clear();

    List<RotationTarget> unaddedTargets = List.from(rotationTargets);
    unaddedTargets
        .sort((a, b) => a.waypointRelativePos.compareTo(b.waypointRelativePos));

    for (int i = 0; i < waypoints.length - 1; i++) {
      for (double t = 0; t < 1.0; t += pathResolution) {
        num actualWaypointPos = i + t;
        num? rotation;

        if (unaddedTargets.isNotEmpty) {
          if ((unaddedTargets[0].waypointRelativePos - actualWaypointPos)
                  .abs() <=
              (unaddedTargets[0].waypointRelativePos -
                      min(actualWaypointPos + pathResolution,
                          waypoints.length - 1))
                  .abs()) {
            rotation = unaddedTargets.removeAt(0).rotationDegrees;
          }
        }

        PathConstraints? constraints;
        for (ConstraintsZone z in constraintZones) {
          if (actualWaypointPos >= z.minWaypointRelativePos &&
              actualWaypointPos <= z.maxWaypointRelativePos) {
            constraints = z.constraints;
            break;
          }
        }

        Point position = GeometryUtil.cubicLerp(
            waypoints[i].anchor,
            waypoints[i].nextControl!,
            waypoints[i + 1].prevControl!,
            waypoints[i + 1].anchor,
            t);
        num dist = (actualWaypointPos == 0)
            ? 0
            : (pathPoints.last.distanceAlongPath +
                (pathPoints.last.position.distanceTo(position)));

        pathPoints.add(
          PathPoint(
            position: position,
            holonomicRotation: rotation,
            constraints: constraints ?? globalConstraints,
            distanceAlongPath: dist,
          ),
        );
      }

      if (i == waypoints.length - 2) {
        pathPoints.add(PathPoint(
          position: waypoints[waypoints.length - 1].anchor,
          holonomicRotation: goalEndState.rotation,
          constraints: globalConstraints,
          distanceAlongPath: pathPoints.last.distanceAlongPath +
              (pathPoints.last.position
                  .distanceTo(waypoints[waypoints.length - 1].anchor)),
        ));
      }
    }

    for (int i = 0; i < pathPoints.length; i++) {
      num curveRadius = _getCurveRadiusAtPoint(i).abs();

      if (curveRadius.isFinite) {
        pathPoints[i].maxV = min(
            sqrt(pathPoints[i].constraints.maxAcceleration * curveRadius.abs()),
            pathPoints[i].constraints.maxVelocity);
      } else {
        pathPoints[i].maxV = pathPoints[i].constraints.maxVelocity;
      }
    }

    pathPoints.last.maxV = goalEndState.velocity;
  }

  num _getCurveRadiusAtPoint(int index) {
    if (pathPoints.length < 3) {
      return double.infinity;
    }

    if (index == 0) {
      return _calculateRadius(pathPoints[index].position,
          pathPoints[index + 1].position, pathPoints[index + 2].position);
    } else if (index == pathPoints.length - 1) {
      return _calculateRadius(pathPoints[index - 2].position,
          pathPoints[index - 1].position, pathPoints[index].position);
    } else {
      return _calculateRadius(pathPoints[index - 1].position,
          pathPoints[index].position, pathPoints[index + 1].position);
    }
  }

  num _calculateRadius(Point a, Point b, Point c) {
    Point vba = a - b;
    Point vbc = c - b;
    num crossZ = (vba.x * vbc.y) - (vba.y * vbc.x);
    num sign = (crossZ < 0) ? 1 : -1;

    num ab = a.distanceTo(b);
    num bc = b.distanceTo(c);
    num ac = a.distanceTo(c);

    num p = (ab + bc + ac) / 2;
    num area = sqrt((p * (p - ab) * (p - bc) * (p - ac)).abs());
    return sign * (ab * bc * ac) / (4 * area);
  }

  PathPlannerPath duplicate(String newName) {
    return PathPlannerPath(
      name: newName,
      waypoints: cloneWaypoints(waypoints),
      globalConstraints: globalConstraints.clone(),
      goalEndState: goalEndState.clone(),
      constraintZones: cloneConstraintZones(constraintZones),
      rotationTargets: cloneRotationTargets(rotationTargets),
      eventMarkers: cloneEventMarkers(eventMarkers),
      pathDir: pathDir,
      fs: fs,
      reversed: reversed,
      folder: folder,
      previewStartingState: previewStartingState?.clone(),
    );
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

  @override
  bool operator ==(Object other) =>
      other is PathPlannerPath &&
      other.runtimeType == runtimeType &&
      other.name == name &&
      other.globalConstraints == globalConstraints &&
      other.goalEndState == goalEndState &&
      other.reversed == reversed &&
      listEquals(other.waypoints, waypoints) &&
      listEquals(other.constraintZones, constraintZones) &&
      listEquals(other.eventMarkers, eventMarkers) &&
      listEquals(other.rotationTargets, rotationTargets);

  @override
  int get hashCode => Object.hash(name, globalConstraints, goalEndState,
      waypoints, constraintZones, eventMarkers, rotationTargets, reversed);
}
