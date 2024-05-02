import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/preview_starting_state.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';

const num epsilon = 0.01;

void main() {
  group('Basic functions', () {
    test('Constructor functions', () {
      var fs = MemoryFileSystem();

      PathPlannerPath path = PathPlannerPath.defaultPath(
        name: 'test',
        pathDir: '/paths',
        fs: fs,
      );

      expect(path.name, 'test');
      expect(path.pathPoints.isNotEmpty, true);

      path = PathPlannerPath(
        name: 'test',
        pathDir: '/paths',
        fs: fs,
        waypoints: [
          Waypoint(
            anchor: const Point(1.0, 1.0),
            nextControl: const Point(2.0, 2.0),
          ),
          Waypoint(
            anchor: const Point(4.0, 1.0),
            prevControl: const Point(3.0, 2.0),
          ),
        ],
        globalConstraints: PathConstraints(maxVelocity: 1.1),
        goalEndState: GoalEndState(velocity: 0.5),
        constraintZones:
            List.generate(3, (index) => ConstraintsZone.defaultZone()),
        rotationTargets: List.generate(4, (index) => RotationTarget()),
        eventMarkers: List.generate(5, (index) => EventMarker.defaultMarker()),
        reversed: false,
        folder: null,
        previewStartingState: null,
        useDefaultConstraints: false,
      );

      expect(path.name, 'test');
      expect(path.waypoints.length, 2);
      expect(path.globalConstraints.maxVelocity, 1.1);
      expect(path.goalEndState.velocity, 0.5);
      expect(path.constraintZones.length, 3);
      expect(path.rotationTargets.length, 4);
      expect(path.eventMarkers.length, 5);
      expect(path.pathPoints.isNotEmpty, true);
    });

    test('toJson/fromJson interoperability', () {
      var fs = MemoryFileSystem();

      PathPlannerPath path = PathPlannerPath(
        name: 'test',
        pathDir: '/paths',
        fs: fs,
        waypoints: [
          Waypoint(
            anchor: const Point(1.0, 1.0),
            nextControl: const Point(2.0, 2.0),
          ),
          Waypoint(
            anchor: const Point(4.0, 1.0),
            prevControl: const Point(3.0, 2.0),
          ),
        ],
        globalConstraints: PathConstraints(maxVelocity: 1.1),
        goalEndState: GoalEndState(velocity: 0.5),
        constraintZones: [ConstraintsZone.defaultZone()],
        rotationTargets: [RotationTarget()],
        eventMarkers: [EventMarker.defaultMarker()],
        reversed: false,
        folder: null,
        previewStartingState: PreviewStartingState(rotation: 10, velocity: 1),
        useDefaultConstraints: false,
      );

      Map<String, dynamic> json = path.toJson();
      PathPlannerPath fromJson =
          PathPlannerPath.fromJsonV1(json, path.name, '/paths', fs);

      expect(fromJson, path);
    });

    test('proper cloning', () {
      var fs = MemoryFileSystem();

      PathPlannerPath path = PathPlannerPath(
        name: 'test',
        pathDir: '/paths',
        fs: fs,
        waypoints: [
          Waypoint(
            anchor: const Point(1.0, 1.0),
            nextControl: const Point(2.0, 2.0),
          ),
          Waypoint(
            anchor: const Point(4.0, 1.0),
            prevControl: const Point(3.0, 2.0),
          ),
        ],
        globalConstraints: PathConstraints(maxVelocity: 1.1),
        goalEndState: GoalEndState(velocity: 0.5),
        constraintZones: [ConstraintsZone.defaultZone()],
        rotationTargets: [RotationTarget()],
        eventMarkers: [EventMarker.defaultMarker()],
        reversed: false,
        folder: null,
        previewStartingState: null,
        useDefaultConstraints: false,
      );
      PathPlannerPath cloned = path.duplicate('test');

      expect(cloned, path);

      cloned.eventMarkers.clear();

      expect(path, isNot(cloned));
    });

    test('equals/hashCode', () {
      var fs = MemoryFileSystem();

      PathPlannerPath path1 = PathPlannerPath(
        name: 'test',
        pathDir: '/paths',
        fs: fs,
        waypoints: [
          Waypoint(
            anchor: const Point(1.0, 1.0),
            nextControl: const Point(2.0, 2.0),
          ),
          Waypoint(
            anchor: const Point(4.0, 1.0),
            prevControl: const Point(3.0, 2.0),
          ),
        ],
        globalConstraints: PathConstraints(maxVelocity: 1.1),
        goalEndState: GoalEndState(velocity: 0.5),
        constraintZones: [ConstraintsZone.defaultZone()],
        rotationTargets: [RotationTarget()],
        eventMarkers: [EventMarker.defaultMarker()],
        reversed: false,
        folder: null,
        previewStartingState: null,
        useDefaultConstraints: false,
      );
      PathPlannerPath path2 = PathPlannerPath(
        name: 'test',
        pathDir: '/paths',
        fs: fs,
        waypoints: [
          Waypoint(
            anchor: const Point(1.0, 1.0),
            nextControl: const Point(2.0, 2.0),
          ),
          Waypoint(
            anchor: const Point(4.0, 1.0),
            prevControl: const Point(3.0, 2.0),
          ),
        ],
        globalConstraints: PathConstraints(maxVelocity: 1.1),
        goalEndState: GoalEndState(velocity: 0.5),
        constraintZones: [ConstraintsZone.defaultZone()],
        rotationTargets: [RotationTarget()],
        eventMarkers: [EventMarker.defaultMarker()],
        reversed: false,
        folder: null,
        previewStartingState: null,
        useDefaultConstraints: false,
      );
      PathPlannerPath path3 = PathPlannerPath(
        name: 'test2',
        pathDir: '/paths',
        fs: fs,
        waypoints: [
          Waypoint(
            anchor: const Point(1.0, 1.5),
            nextControl: const Point(2.0, 2.0),
          ),
          Waypoint(
            anchor: const Point(4.0, 1.0),
            prevControl: const Point(3.0, 2.1),
          ),
        ],
        globalConstraints: PathConstraints(maxVelocity: 1.0),
        goalEndState: GoalEndState(velocity: 0.2),
        constraintZones: [],
        rotationTargets: [],
        eventMarkers: [],
        reversed: false,
        folder: null,
        previewStartingState: null,
        useDefaultConstraints: false,
      );

      expect(path2, path1);
      expect(path3, isNot(path1));

      expect(path2.hashCode, isPositive);
      expect(path3.hashCode, isNot(path1.hashCode));
    });
  });

  test('add waypoint', () {
    var fs = MemoryFileSystem();

    PathPlannerPath path = PathPlannerPath(
      name: 'test',
      pathDir: '/paths',
      fs: fs,
      waypoints: [
        Waypoint(
          anchor: const Point(1.0, 1.0),
          nextControl: const Point(2.0, 2.0),
        ),
        Waypoint(
          anchor: const Point(4.0, 1.0),
          prevControl: const Point(3.0, 2.0),
        ),
      ],
      globalConstraints: PathConstraints(maxVelocity: 1.1),
      goalEndState: GoalEndState(velocity: 0.5),
      constraintZones: [ConstraintsZone.defaultZone()],
      rotationTargets: [RotationTarget()],
      eventMarkers: [EventMarker.defaultMarker()],
      reversed: false,
      folder: null,
      previewStartingState: null,
      useDefaultConstraints: false,
    );

    path.addWaypoint(const Point(6.0, 1.0));

    expect(path.waypoints.length, 3);
    expect(path.waypoints.last.anchor, const Point(6.0, 1.0));
    expect(path.waypoints.last.prevControl, isNotNull);
    expect(path.waypoints.last.prevControl!.x, closeTo(5.5, epsilon));
    expect(path.waypoints.last.prevControl!.y, closeTo(0.5, epsilon));
    expect(path.waypoints[1].nextControl, isNotNull);
  });

  test('insert waypoint', () {
    var fs = MemoryFileSystem();

    PathPlannerPath path = PathPlannerPath(
      name: 'test',
      pathDir: '/paths',
      fs: fs,
      waypoints: [
        Waypoint(
          anchor: const Point(1.0, 1.0),
          nextControl: const Point(2.0, 2.0),
        ),
        Waypoint(
          anchor: const Point(4.0, 1.0),
          prevControl: const Point(3.0, 2.0),
        ),
      ],
      globalConstraints: PathConstraints(maxVelocity: 1.1),
      goalEndState: GoalEndState(velocity: 0.5),
      constraintZones: [
        ConstraintsZone(
          minWaypointRelativePos: 0.2,
          maxWaypointRelativePos: 0.4,
          constraints: PathConstraints(),
        ),
      ],
      rotationTargets: [RotationTarget(waypointRelativePos: 0.6)],
      eventMarkers: [
        EventMarker(
          waypointRelativePos: 0.5,
          command:
              SequentialCommandGroup(commands: [NamedCommand(name: 'testcmd')]),
        ),
      ],
      reversed: false,
      folder: null,
      previewStartingState: null,
      useDefaultConstraints: false,
    );

    path.insertWaypointAfter(1);
    expect(path.waypoints.length, 2);

    path.insertWaypointAfter(0);
    expect(path.waypoints.length, 3);
    expect(path.waypoints[1].anchor, const Point(2.5, 1.75));
    expect(path.waypoints[1].prevControl, const Point(2.25, 1.875));
    expect(path.waypoints[1].nextControl, const Point(2.75, 1.625));
    expect(path.constraintZones[0].minWaypointRelativePos, 0.4);
    expect(path.constraintZones[0].maxWaypointRelativePos, 0.8);
    expect(path.rotationTargets[0].waypointRelativePos, 1.2);
    expect(path.eventMarkers[0].waypointRelativePos, 1.0);

    path.insertWaypointAfter(0);
    expect(path.waypoints.length, 4);
    expect(path.rotationTargets[0].waypointRelativePos, 2.2);
  });

  group('file management', () {
    late MemoryFileSystem fs;
    final String pathsPath = Platform.isWindows ? 'C:\\paths' : '/paths';

    setUp(() => fs = MemoryFileSystem(
        style: Platform.isWindows
            ? FileSystemStyle.windows
            : FileSystemStyle.posix));

    test('rename', () {
      Directory pathDir = fs.directory(pathsPath);
      fs.file(join(pathDir.path, 'test.path')).createSync(recursive: true);

      PathPlannerPath path = PathPlannerPath.defaultPath(
          name: 'test', pathDir: pathDir.path, fs: fs);

      path.renamePath('renamed');

      expect(path.name, 'renamed');
      expect(fs.file(join(pathDir.path, 'test.path')).existsSync(), false);
      expect(fs.file(join(pathDir.path, 'renamed.path')).existsSync(), true);
    });

    test('delete', () {
      Directory pathDir = fs.directory(pathsPath);
      fs.file(join(pathDir.path, 'test.path')).createSync(recursive: true);

      PathPlannerPath path = PathPlannerPath.defaultPath(
          name: 'test', pathDir: pathDir.path, fs: fs);

      path.deletePath();

      expect(fs.file(join(pathDir.path, 'test.path')).existsSync(), false);
    });

    test('load paths in dir', () async {
      Directory pathDir = fs.directory(pathsPath);
      pathDir.createSync(recursive: true);

      PathPlannerPath path1 = PathPlannerPath.defaultPath(
          name: 'test1', pathDir: pathDir.path, fs: fs);
      PathPlannerPath path2 = PathPlannerPath.defaultPath(
          name: 'test2', pathDir: pathDir.path, fs: fs);
      path2.eventMarkers.add(EventMarker.defaultMarker());

      fs
          .file(join(pathDir.path, 'test1.path'))
          .writeAsStringSync(jsonEncode(path1.toJson()));
      fs
          .file(join(pathDir.path, 'test2.path'))
          .writeAsStringSync(jsonEncode(path2.toJson()));

      List<PathPlannerPath> loaded =
          await PathPlannerPath.loadAllPathsInDir(pathDir.path, fs);

      expect(loaded.length, 2);

      // Sort paths by name so they should be in the order: path1, path2
      loaded.sort((a, b) => a.name.compareTo(b.name));

      expect(loaded[0], path1);
      expect(loaded[1], path2);
    });

    test('generate and save', () {
      Directory pathDir = fs.directory(pathsPath);
      pathDir.createSync(recursive: true);

      PathPlannerPath path = PathPlannerPath.defaultPath(
          name: 'test', pathDir: pathDir.path, fs: fs);
      path.constraintZones.add(ConstraintsZone.defaultZone());

      path.generateAndSavePath();

      File pathFile = fs.file(join(pathDir.path, 'test.path'));
      expect(pathFile.existsSync(), true);

      String fileContent = pathFile.readAsStringSync();
      Map<String, dynamic> fileJson = jsonDecode(fileContent);
      expect(
          const DeepCollectionEquality().equals(fileJson, path.toJson()), true);
    });
  });

  test('hasEmptyNamedCommand', () {
    PathPlannerPath path =
        PathPlannerPath.defaultPath(pathDir: '/paths', fs: MemoryFileSystem());

    path.eventMarkers.add(
      EventMarker(
        command: SequentialCommandGroup(
          commands: [
            ParallelCommandGroup(commands: [
              NamedCommand(),
            ]),
          ],
        ),
      ),
    );

    expect(path.hasEmptyNamedCommand(), true);
  });
}
