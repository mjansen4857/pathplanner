import 'dart:math';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/simulator/trajectory_generator.dart';
import 'package:pathplanner/util/pose2d.dart';

void main() {
  test('simulate path', () {
    PathPlannerPath test = PathPlannerPath(
      name: '',
      waypoints: [
        Waypoint(
          anchor: const Point(1, 1),
          nextControl: const Point(3, 1),
        ),
        Waypoint(
          prevControl: const Point(4, 3),
          anchor: const Point(6, 3),
        ),
      ],
      globalConstraints: PathConstraints(),
      goalEndState: GoalEndState(),
      constraintZones: [],
      rotationTargets: [
        RotationTarget(
          waypointRelativePos: 0.5,
          rotationDegrees: 45,
          rotateFast: true,
        ),
      ],
      eventMarkers: [],
      pathDir: '',
      fs: MemoryFileSystem(),
      reversed: false,
      folder: null,
      previewStartingState: null,
      useDefaultConstraints: false,
    );

    Trajectory sim = Trajectory.simulate(test, 0, 0,
        maxModuleSpeed: 4.5, driveBaseRadius: 0.425);

    // Basic coverage test, expand in future
    expect(sim.states.last.time, closeTo(2.83, 0.05));

    expect(sim.sample(0.5).velocity, closeTo(1.5, 0.05));
  });

  test('copyWithTime', () {
    TrajectoryState state =
        TrajectoryState(time: 0.0, position: const Point(1.0, 1.0));

    TrajectoryState copied = state.copyWithTime(1.0);

    expect(copied.time, 1.0);
    expect(copied.position, state.position);
  });

  test('simulate auto', () {
    PathPlannerPath test = PathPlannerPath(
      name: '',
      waypoints: [
        Waypoint(
          anchor: const Point(1, 1),
          nextControl: const Point(3, 1),
        ),
        Waypoint(
          prevControl: const Point(4, 3),
          anchor: const Point(6, 3),
        ),
      ],
      globalConstraints: PathConstraints(),
      goalEndState: GoalEndState(),
      constraintZones: [
        ConstraintsZone(
            constraints: PathConstraints(),
            minWaypointRelativePos: 0.2,
            maxWaypointRelativePos: 0.4),
      ],
      rotationTargets: [
        RotationTarget(waypointRelativePos: 0.5, rotationDegrees: 45),
      ],
      eventMarkers: [],
      pathDir: '',
      fs: MemoryFileSystem(),
      reversed: false,
      folder: null,
      previewStartingState: null,
      useDefaultConstraints: false,
    );

    // Basic coverage tests, expand in future
    Trajectory? sim = TrajectoryGenerator.simulateAuto([], null, 4.5, 0.425);
    expect(sim, isNull);

    sim = TrajectoryGenerator.simulateAuto(
        [test], Pose2d(position: const Point(1, 1)), 4.5, 0.425);
    expect(sim, isNotNull);
    expect(sim!.states.last.time, closeTo(2.83, 0.05));

    sim = TrajectoryGenerator.simulateAuto(
        [test], Pose2d(position: const Point(0, 0)), 4.5, 0.425);
    expect(sim, isNotNull);
    expect(sim!.states.last.time, closeTo(3.67, 0.05));

    sim = TrajectoryGenerator.simulateAuto(
        [test], Pose2d(position: const Point(8, 2)), 4.5, 0.425);
    expect(sim, isNotNull);
    expect(sim!.states.last.time, closeTo(1.73, 0.05));

    sim = TrajectoryGenerator.simulateAuto(
        [test], Pose2d(position: const Point(3, 1)), 4.5, 0.425);
    expect(sim, isNotNull);
    expect(sim!.states.last.time, closeTo(2.58, 0.05));
  });
}
