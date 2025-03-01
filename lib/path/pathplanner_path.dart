import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/path/point_towards_zone.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';

const double targetIncrement = 0.05;
const double targetSpacing = 0.2;
const String fileVersion = '2025.0';

class PathPlannerPath {
  String name;
  List<Waypoint> waypoints;
  List<PathPoint> pathPoints;
  PathConstraints globalConstraints;
  GoalEndState goalEndState;
  List<ConstraintsZone> constraintZones;
  List<PointTowardsZone> pointTowardsZones;
  List<RotationTarget> rotationTargets;
  List<EventMarker> eventMarkers;
  bool reversed;
  IdealStartingState idealStartingState;
  String? folder;
  bool useDefaultConstraints;

  FileSystem fs;
  String pathDir;

  // Stuff used for UI
  bool waypointsExpanded = false;
  bool globalConstraintsExpanded = false;
  bool goalEndStateExpanded = false;
  bool rotationTargetsExpanded = false;
  bool eventMarkersExpanded = false;
  bool constraintZonesExpanded = false;
  bool pointTowardsZonesExpanded = false;
  bool previewStartingStateExpanded = false;
  bool pathOptimizationExpanded = false;
  DateTime lastModified = DateTime.now().toUtc();

  PathPlannerPath({
    required this.name,
    required this.waypoints,
    required this.globalConstraints,
    required this.goalEndState,
    required this.constraintZones,
    required this.pointTowardsZones,
    required this.rotationTargets,
    required this.eventMarkers,
    required this.pathDir,
    required this.fs,
    required this.reversed,
    required this.folder,
    required this.idealStartingState,
    required this.useDefaultConstraints,
  }) : pathPoints = [] {
    // Set the up the values of linked waypoints
    for (int i = 0; i < waypoints.length; i++) {
      final w = waypoints[i];
      if (w.linkedName != null) {
        if (i == 0) {
          // Link rotation will be from ideal starting state
          Waypoint.linked[w.linkedName!] = Pose2d(w.anchor, idealStartingState.rotation);
        } else if (i == waypoints.length - 1) {
          // Link rotation will be from goal end state
          Waypoint.linked[w.linkedName!] = Pose2d(w.anchor, goalEndState.rotation);
        } else if (!Waypoint.linked.containsKey(w.linkedName!)) {
          // If waypoint is not already in linked map, just use a 0 rotation for now
          Waypoint.linked[w.linkedName!] = Pose2d(w.anchor, const Rotation2d());
        }
      }
    }

    generatePathPoints();
  }

  PathPlannerPath.defaultPath({
    required this.pathDir,
    required this.fs,
    this.name = 'New Path',
    this.folder,
    PathConstraints? constraints,
  })  : waypoints = [],
        pathPoints = [],
        globalConstraints = constraints ?? PathConstraints(),
        goalEndState = GoalEndState(0, const Rotation2d()),
        constraintZones = [],
        pointTowardsZones = [],
        rotationTargets = [],
        eventMarkers = [],
        reversed = false,
        idealStartingState = IdealStartingState(0, const Rotation2d()),
        useDefaultConstraints = true {
    waypoints.addAll([
      Waypoint(
        anchor: const Translation2d(2.0, 7.0),
        nextControl: const Translation2d(3.0, 7.0),
      ),
      Waypoint(
        prevControl: const Translation2d(3.0, 6.0),
        anchor: const Translation2d(4.0, 6.0),
      ),
    ]);

    generatePathPoints();
  }

  PathPlannerPath.fromJson(Map<String, dynamic> json, String name, String pathsDir, FileSystem fs)
      : this(
          pathDir: pathsDir,
          fs: fs,
          name: name,
          waypoints: [
            for (final waypointJson in json['waypoints']) Waypoint.fromJson(waypointJson),
          ],
          globalConstraints: PathConstraints.fromJson(json['globalConstraints'] ?? {}),
          goalEndState: GoalEndState.fromJson(json['goalEndState'] ?? {}),
          constraintZones: [
            for (final zoneJson in json['constraintZones'] ?? [])
              ConstraintsZone.fromJson(zoneJson),
          ],
          pointTowardsZones: [
            for (final zoneJson in json['pointTowardsZones'] ?? [])
              PointTowardsZone.fromJson(zoneJson),
          ],
          rotationTargets: [
            for (final targetJson in json['rotationTargets'] ?? [])
              RotationTarget.fromJson(targetJson),
          ],
          eventMarkers: [
            for (final markerJson in json['eventMarkers'] ?? []) EventMarker.fromJson(markerJson),
          ],
          reversed: json['reversed'] ?? false,
          folder: json['folder'],
          idealStartingState: IdealStartingState.fromJson(json['previewStartingState'] ?? {}),
          useDefaultConstraints: json['useDefaultConstraints'] ?? false,
        );

  void generateAndSavePath() {
    generatePathPoints();
    saveFile();
  }

  void saveFile() {
    try {
      File pathFile = fs.file(join(pathDir, '$name.path'));
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      pathFile.writeAsString(encoder.convert(this));
      lastModified = DateTime.now().toUtc();
    } catch (ex, stack) {
      Log.error('Failed to save path: $name', ex, stack);
    }
  }

  static Future<List<PathPlannerPath>> loadAllPathsInDir(String pathsDir, FileSystem fs) async {
    List<PathPlannerPath> paths = [];

    List<FileSystemEntity> files = fs.directory(pathsDir).listSync();
    for (FileSystemEntity e in files) {
      if (e.path.endsWith('.path')) {
        final file = fs.file(e.path);
        String jsonStr = await file.readAsString();
        try {
          Map<String, dynamic> json = jsonDecode(jsonStr);
          String pathName = basenameWithoutExtension(e.path);

          PathPlannerPath path = PathPlannerPath.fromJson(json, pathName, pathsDir, fs);
          path.lastModified = (await file.lastModified()).toUtc();

          if (json['version'] != fileVersion) {
            path.saveFile();
          }

          paths.add(path);
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
    // Make sure rotation targets and event markers are sorted
    final sortedTargets = List.of(rotationTargets)
        .sorted((a, b) => a.waypointRelativePos.compareTo(b.waypointRelativePos));
    final sortedMarkers = List.of(eventMarkers)
        .sorted((a, b) => a.waypointRelativePos.compareTo(b.waypointRelativePos));

    return {
      'version': fileVersion,
      'waypoints': [
        for (final w in waypoints) w.toJson(),
      ],
      'rotationTargets': [
        for (final t in sortedTargets) t.toJson(),
      ],
      'constraintZones': [
        for (final z in constraintZones) z.toJson(),
      ],
      'pointTowardsZones': [
        for (final z in pointTowardsZones) z.toJson(),
      ],
      'eventMarkers': [
        for (final m in sortedMarkers) m.toJson(),
      ],
      'globalConstraints': globalConstraints.toJson(),
      'goalEndState': goalEndState.toJson(),
      'reversed': reversed,
      'folder': folder,
      'previewStartingState': idealStartingState.toJson(),
      'useDefaultConstraints': useDefaultConstraints,
    };
  }

  void addWaypoint(Translation2d anchorPos) {
    waypoints[waypoints.length - 1].addNextControl();
    waypoints.add(
      Waypoint(
        prevControl: (waypoints[waypoints.length - 1].nextControl! + anchorPos) * 0.5,
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
    Translation2d anchorPos = GeometryUtil.cubicLerp(
        before.anchor, before.nextControl!, after.prevControl!, after.anchor, 0.5);

    Waypoint toAdd = Waypoint(
      anchor: anchorPos,
      prevControl: (anchorPos + before.nextControl!) * 0.5,
    );
    toAdd.addNextControl();

    waypoints.insert(waypointIdx + 1, toAdd);

    for (RotationTarget t in rotationTargets) {
      t.waypointRelativePos =
          _adjustInsertedWaypointRelativePos(t.waypointRelativePos, waypointIdx + 1);
    }

    for (EventMarker m in eventMarkers) {
      m.waypointRelativePos =
          _adjustInsertedWaypointRelativePos(m.waypointRelativePos, waypointIdx + 1);
    }

    for (ConstraintsZone z in constraintZones) {
      z.minWaypointRelativePos =
          _adjustInsertedWaypointRelativePos(z.minWaypointRelativePos, waypointIdx + 1);
      z.maxWaypointRelativePos =
          _adjustInsertedWaypointRelativePos(z.maxWaypointRelativePos, waypointIdx + 1);
    }

    for (PointTowardsZone z in pointTowardsZones) {
      z.minWaypointRelativePos =
          _adjustInsertedWaypointRelativePos(z.minWaypointRelativePos, waypointIdx + 1);
      z.maxWaypointRelativePos =
          _adjustInsertedWaypointRelativePos(z.maxWaypointRelativePos, waypointIdx + 1);
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

  void _addNamedCommandsToEvents(Command command) {
    if (command is NamedCommand) {
      if (command.name != null) {
        ProjectPage.events.add(command.name!);
        return;
      }
    }

    if (command is CommandGroup) {
      for (Command cmd in command.commands) {
        _addNamedCommandsToEvents(cmd);
      }
    }
  }

  bool hasEmptyNamedCommand() {
    for (EventMarker m in eventMarkers) {
      if (m.command == null) {
        continue;
      }

      bool hasEmpty = _hasEmptyNamedCommand(m.command!);
      if (hasEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasEmptyNamedCommand(Command command) {
    if (command is NamedCommand && command.name == null) {
      return true;
    } else if (command is CommandGroup) {
      for (final cmd in command.commands) {
        if (_hasEmptyNamedCommand(cmd)) {
          return true;
        }
      }
    }

    return false;
  }

  PathConstraints _constraintsForPos(num waypointPos) {
    for (final z in constraintZones) {
      if (waypointPos >= z.minWaypointRelativePos && waypointPos <= z.maxWaypointRelativePos) {
        return z.constraints;
      }
    }

    // Check if the constraints should be unlimited
    if (globalConstraints.unlimited) {
      return PathConstraints(
        maxVelocityMPS: double.infinity,
        maxAccelerationMPSSq: double.infinity,
        maxAngularVelocityDeg: double.infinity,
        maxAngularAccelerationDeg: double.infinity,
        nominalVoltage: globalConstraints.nominalVoltage,
        unlimited: true,
      );
    }

    return globalConstraints;
  }

  PointTowardsZone? _pointZoneForPos(num waypointPos) {
    for (final z in pointTowardsZones) {
      if (waypointPos >= z.minWaypointRelativePos && waypointPos <= z.maxWaypointRelativePos) {
        return z;
      }
    }
    return null;
  }

  void generatePathPoints() {
    // Add all event names in this path to the available names
    for (EventMarker m in eventMarkers) {
      if (m.name.isNotEmpty) {
        ProjectPage.events.add(m.name);
      }
      if (m.command != null) {
        _addNamedCommandsToEvents(m.command!);
      }
    }

    pathPoints.clear();

    final unaddedTargets =
        rotationTargets.sorted((a, b) => a.waypointRelativePos.compareTo(b.waypointRelativePos));

    // first point
    pathPoints.add(PathPoint(
      position: samplePath(0.0),
      rotationTarget: null,
      constraints: _constraintsForPos(0.0),
      waypointPos: 0.0,
    ));

    double pos = targetIncrement;
    while (pos < waypoints.length - 1) {
      var position = samplePath(pos);

      num distance = pathPoints.last.position.getDistance(position);
      if (distance <= 0.01) {
        pos = min(pos + targetIncrement, waypoints.length - 1);
        continue;
      }

      num prevPos = pos - targetIncrement;

      num delta = distance - targetSpacing;
      if (delta > targetSpacing * 0.25) {
        // Points are too far apart, increment waypoint relative pos by correct amount
        double correctIncrement = (targetSpacing * targetIncrement) / distance;
        pos = pos - targetIncrement + correctIncrement;

        position = samplePath(pos);

        if (pathPoints.last.position.getDistance(position) - targetSpacing > targetSpacing * 0.25) {
          // Points are still too far apart. Probably because of weird control
          // point placement. Just cut the correct increment in half and hope for the best
          pos = pos - (correctIncrement * 0.5);
          position = samplePath(pos);
        }
      } else if (delta < -targetSpacing * 0.25) {
        // Points are too close, increment waypoint relative pos by correct amount
        double correctIncrement = (targetSpacing * targetIncrement) / distance;
        pos = pos - targetIncrement + correctIncrement;

        position = samplePath(pos);

        if (pathPoints.last.position.getDistance(position) - targetSpacing <
            -targetSpacing * 0.25) {
          // Points are still too close. Probably because of weird control
          // point placement. Just cut the correct increment in half and hope for the best
          pos = pos + (correctIncrement * 0.5);
          position = samplePath(pos);
        }
      }

      // Add rotation targets
      RotationTarget? target;
      PathPoint prevPoint = pathPoints.last;

      while (unaddedTargets.isNotEmpty &&
          unaddedTargets[0].waypointRelativePos >= prevPos &&
          unaddedTargets[0].waypointRelativePos <= pos) {
        if ((unaddedTargets[0].waypointRelativePos - prevPos).abs() < 0.001) {
          // Close enough to prev pos
          prevPoint.rotationTarget = unaddedTargets.removeAt(0);
        } else if ((unaddedTargets[0].waypointRelativePos - pos).abs() < 0.001) {
          // Close enough to next pos
          target = unaddedTargets.removeAt(0);
        } else {
          // We should insert a point at the exact position
          RotationTarget t = unaddedTargets.removeAt(0);
          pathPoints.add(PathPoint(
            position: samplePath(t.waypointRelativePos),
            rotationTarget: t,
            constraints: _constraintsForPos(t.waypointRelativePos),
            waypointPos: t.waypointRelativePos,
          ));
        }
      }

      pathPoints.add(PathPoint(
        position: position,
        rotationTarget: target,
        constraints: _constraintsForPos(pos),
        waypointPos: pos,
      ));
      pos = min(pos + targetIncrement, waypoints.length - 1);
    }

    // Keep trying to add the end point until its close enough to the prev point
    num trueIncrement = (waypoints.length - 1) - (pos - targetIncrement);
    pos = waypoints.length - 1;
    bool invalid = true;
    while (invalid) {
      var position = samplePath(pos);

      num distance = pathPoints.last.position.getDistance(position);
      if (distance <= 0.01) {
        invalid = false;
        break;
      }

      num prevPos = pos - trueIncrement;

      num delta = distance - targetSpacing;
      if (delta > targetSpacing * 0.25) {
        // Points are too far apart, increment waypoint relative pos by correct amount
        double correctIncrement = (targetSpacing * trueIncrement) / distance;
        pos = pos - trueIncrement + correctIncrement;
        trueIncrement = correctIncrement;

        position = samplePath(pos);

        if (pathPoints.last.position.getDistance(position) - targetSpacing > targetSpacing * 0.25) {
          // Points are still too far apart. Probably because of weird control
          // point placement. Just cut the correct increment in half and hope for the best
          pos = pos - (correctIncrement * 0.5);
          trueIncrement = correctIncrement * 0.5;
          position = samplePath(pos);
        }
      } else {
        invalid = false;
      }

      // Add a rotation target to the previous point if it is closer to it than
      // the current point
      if (unaddedTargets.isNotEmpty) {
        if ((unaddedTargets[0].waypointRelativePos - prevPos).abs() <=
            (unaddedTargets[0].waypointRelativePos - pos).abs()) {
          pathPoints.last.rotationTarget = unaddedTargets.removeAt(0);
        }
      }

      pathPoints.add(PathPoint(
        position: position,
        rotationTarget: null,
        constraints: _constraintsForPos(pos),
        waypointPos: pos,
      ));
      pos = waypoints.length - 1;
    }

    // Force end rotation target to end state rotation
    pathPoints.last.rotationTarget = RotationTarget(waypoints.length - 1, goalEndState.rotation);

    for (int i = 1; i < pathPoints.length - 1; i++) {
      num curveRadius = GeometryUtil.calculateRadius(
          pathPoints[i - 1].position, pathPoints[i].position, pathPoints[i + 1].position);

      if (!curveRadius.isFinite) {
        continue;
      }

      if (curveRadius.abs() < 0.25) {
        // Curve radius is too tight for default spacing, insert 4 more points
        num before1WaypointPos =
            MathUtil.interpolate(pathPoints[i - 1].waypointPos, pathPoints[i].waypointPos, 0.33);
        num before2WaypointPos =
            MathUtil.interpolate(pathPoints[i - 1].waypointPos, pathPoints[i].waypointPos, 0.67);
        num after1WaypointPos =
            MathUtil.interpolate(pathPoints[i].waypointPos, pathPoints[i + 1].waypointPos, 0.33);
        num after2WaypointPos =
            MathUtil.interpolate(pathPoints[i].waypointPos, pathPoints[i + 1].waypointPos, 0.67);

        PathPoint before1 = PathPoint(
          position: samplePath(before1WaypointPos),
          rotationTarget: null,
          constraints: pathPoints[i].constraints,
          waypointPos: before1WaypointPos,
        );
        PathPoint before2 = PathPoint(
          position: samplePath(before2WaypointPos),
          rotationTarget: null,
          constraints: pathPoints[i].constraints,
          waypointPos: before2WaypointPos,
        );
        PathPoint after1 = PathPoint(
          position: samplePath(after1WaypointPos),
          rotationTarget: null,
          constraints: pathPoints[i].constraints,
          waypointPos: after1WaypointPos,
        );
        PathPoint after2 = PathPoint(
          position: samplePath(after2WaypointPos),
          rotationTarget: null,
          constraints: pathPoints[i].constraints,
          waypointPos: after2WaypointPos,
        );

        pathPoints.insert(i, before2);
        pathPoints.insert(i, before1);
        pathPoints.insert(i + 3, after2);
        pathPoints.insert(i + 3, after1);
        i += 4;
      } else if (curveRadius.abs() < 0.5) {
        // Curve radius is too tight for default spacing, insert 2 more points
        num beforeWaypointPos =
            MathUtil.interpolate(pathPoints[i - 1].waypointPos, pathPoints[i].waypointPos, 0.5);
        num afterWaypointPos =
            MathUtil.interpolate(pathPoints[i].waypointPos, pathPoints[i + 1].waypointPos, 0.5);

        PathPoint before = PathPoint(
          position: samplePath(beforeWaypointPos),
          rotationTarget: null,
          constraints: pathPoints[i].constraints,
          waypointPos: beforeWaypointPos,
        );
        PathPoint after = PathPoint(
          position: samplePath(afterWaypointPos),
          rotationTarget: null,
          constraints: pathPoints[i].constraints,
          waypointPos: afterWaypointPos,
        );

        pathPoints.insert(i, before);
        pathPoints.insert(i + 2, after);
        i += 2;
      }
    }

    for (int i = 0; i < pathPoints.length; i++) {
      num curveRadius = _getCurveRadiusAtPoint(i).abs();

      if (curveRadius.isFinite) {
        pathPoints[i].maxV = min(
            sqrt(pathPoints[i].constraints.maxAccelerationMPSSq * curveRadius.abs()),
            pathPoints[i].constraints.maxVelocityMPS);
      } else {
        pathPoints[i].maxV = pathPoints[i].constraints.maxVelocityMPS;
      }

      if (i > 0) {
        pathPoints[i].distanceAlongPath = pathPoints[i - 1].distanceAlongPath +
            pathPoints[i].position.getDistance(pathPoints[i - 1].position);
      }

      if (i != 0 && i != pathPoints.length - 1) {
        // Set the rotation target for point towards zones
        final zone = _pointZoneForPos(pathPoints[i].waypointPos);
        if (zone != null) {
          final angleToTarget = (zone.fieldPosition - pathPoints[i].position).angle;
          final rotation = angleToTarget + zone.rotationOffset;
          pathPoints[i].rotationTarget = RotationTarget(pathPoints[i].waypointPos, rotation, false);
        }
      }
    }

    pathPoints.last.maxV = goalEndState.velocityMPS;
  }

  Translation2d samplePath(num waypointRelativePos) {
    num pos = MathUtil.clamp(waypointRelativePos, 0, waypoints.length - 1);

    int i = pos.floor();
    if (i == waypoints.length - 1) {
      i--;
    }

    num t = pos - i;

    return GeometryUtil.cubicLerp(waypoints[i].anchor, waypoints[i].nextControl!,
        waypoints[i + 1].prevControl!, waypoints[i + 1].anchor, t);
  }

  num _getCurveRadiusAtPoint(int index) {
    if (pathPoints.length < 3) {
      return double.infinity;
    }

    if (index == 0) {
      return GeometryUtil.calculateRadius(pathPoints[index].position,
          pathPoints[index + 1].position, pathPoints[index + 2].position);
    } else if (index == pathPoints.length - 1) {
      return GeometryUtil.calculateRadius(pathPoints[index - 2].position,
          pathPoints[index - 1].position, pathPoints[index].position);
    } else {
      return GeometryUtil.calculateRadius(pathPoints[index - 1].position,
          pathPoints[index].position, pathPoints[index + 1].position);
    }
  }

  PathPlannerPath duplicate(String newName) {
    return PathPlannerPath(
      name: newName,
      waypoints: cloneWaypoints(waypoints),
      globalConstraints: globalConstraints.clone(),
      goalEndState: goalEndState.clone(),
      constraintZones: cloneConstraintZones(constraintZones),
      pointTowardsZones: clonePointTowardsZones(pointTowardsZones),
      rotationTargets: cloneRotationTargets(rotationTargets),
      eventMarkers: cloneEventMarkers(eventMarkers),
      pathDir: pathDir,
      fs: fs,
      reversed: reversed,
      folder: folder,
      idealStartingState: idealStartingState.clone(),
      useDefaultConstraints: useDefaultConstraints,
    );
  }

  PathPlannerPath reverse(String newName) {
    Stopwatch s = Stopwatch()..start();
    final result = PathPlannerPath(
      name: newName,
      waypoints: reverseWaypoints(waypoints),
      globalConstraints: globalConstraints.clone(),
      goalEndState: goalEndState.reverse(),
      constraintZones: cloneConstraintZones(constraintZones),
      pointTowardsZones: clonePointTowardsZones(pointTowardsZones),
      rotationTargets: reverseRotationTargets(rotationTargets),
      eventMarkers: cloneEventMarkers(eventMarkers),
      pathDir: pathDir,
      fs: fs,
      reversed: reversed,
      folder: folder,
      idealStartingState: idealStartingState.reverse(),
      useDefaultConstraints: useDefaultConstraints,
    );
    try {
      File pathFile = fs.file(join(pathDir, '$newName.path'));
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      pathFile.writeAsString(encoder.convert(result));
      lastModified = DateTime.now().toUtc();
      Log.debug('Reversed and Saved "$name.path" in ${s.elapsedMilliseconds}ms');
    } catch (ex, stack) {
      Log.error('Failed to save path', ex, stack);
    }
    return result;
  }

  PathPlannerPath reverseH(String newName) {
    Stopwatch s = Stopwatch()..start();
    final result = PathPlannerPath(
      name: newName,
      waypoints: reverseHWaypoints(waypoints),
      globalConstraints: globalConstraints.clone(),
      goalEndState: goalEndState.reverseH(),
      constraintZones: cloneConstraintZones(constraintZones),
      pointTowardsZones: clonePointTowardsZones(pointTowardsZones),
      rotationTargets: reverseHRotationTargets(rotationTargets),
      eventMarkers: cloneEventMarkers(eventMarkers),
      pathDir: pathDir,
      fs: fs,
      reversed: reversed,
      folder: folder,
      idealStartingState: idealStartingState.reverseH(),
      useDefaultConstraints: useDefaultConstraints,
    );
    try {
      File pathFile = fs.file(join(pathDir, '$newName.path'));
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      pathFile.writeAsString(encoder.convert(result));
      lastModified = DateTime.now().toUtc();
      Log.debug('Reversed and Saved "$name.path" in ${s.elapsedMilliseconds}ms');
    } catch (ex, stack) {
      Log.error('Failed to save path', ex, stack);
    }
    return result;
  }

  List<Translation2d> get pathPositions => [
        for (final p in pathPoints) p.position,
      ];

  static List<Waypoint> cloneWaypoints(List<Waypoint> waypoints) {
    return [
      for (final waypoint in waypoints) waypoint.clone(),
    ];
  }

  static List<Waypoint> reverseWaypoints(List<Waypoint> waypoints) {
    return [
      for (final waypoint in waypoints) waypoint.reverse(),
    ];
  }

  static List<Waypoint> reverseHWaypoints(List<Waypoint> waypoints) {
    return [
      for (final waypoint in waypoints) waypoint.reverseH(),
    ];
  }

  static List<ConstraintsZone> cloneConstraintZones(List<ConstraintsZone> zones) {
    return [
      for (final zone in zones) zone.clone(),
    ];
  }

  static List<PointTowardsZone> clonePointTowardsZones(List<PointTowardsZone> zones) {
    return [
      for (final zone in zones) zone.clone(),
    ];
  }

  static List<RotationTarget> cloneRotationTargets(List<RotationTarget> targets) {
    return [
      for (final target in targets) target.clone(),
    ];
  }

  static List<RotationTarget> reverseRotationTargets(List<RotationTarget> targets) {
    return [
      for (final target in targets) target.reverse(),
    ];
  }

  static List<RotationTarget> reverseHRotationTargets(List<RotationTarget> targets) {
    return [
      for (final target in targets) target.reverseH(),
    ];
  }

  static List<EventMarker> cloneEventMarkers(List<EventMarker> markers) {
    return [
      for (final marker in markers) marker.clone(),
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
      listEquals(other.pointTowardsZones, pointTowardsZones) &&
      listEquals(other.eventMarkers, eventMarkers) &&
      listEquals(other.rotationTargets, rotationTargets);

  @override
  int get hashCode => Object.hash(name, globalConstraints, goalEndState, waypoints, constraintZones,
      eventMarkers, rotationTargets, reversed);
}
