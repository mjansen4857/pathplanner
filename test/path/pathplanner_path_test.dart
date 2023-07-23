import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/none_command.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';

const num epsilon = 0.01;

void main() {
  group('Basic functions', () {
    test('Constructor functions', () {
      PathPlannerPath path = PathPlannerPath.defaultPath(name: 'test');

      expect(path.name, 'test');
      expect(path.pathPoints.isNotEmpty, true);

      path = PathPlannerPath(
        name: 'test',
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
      PathPlannerPath path = PathPlannerPath(
        name: 'test',
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
      );

      Map<String, dynamic> json = path.toJson();
      PathPlannerPath fromJson = PathPlannerPath.fromJsonV1(json, path.name);

      expect(fromJson, path);
    });

    test('proper cloning', () {
      PathPlannerPath path = PathPlannerPath(
        name: 'test',
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
      );
      PathPlannerPath cloned = path.duplicate('test');

      expect(cloned, path);

      cloned.eventMarkers.clear();

      expect(path, isNot(cloned));
    });

    test('equals/hashCode', () {
      PathPlannerPath path1 = PathPlannerPath(
        name: 'test',
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
      );
      PathPlannerPath path2 = PathPlannerPath(
        name: 'test',
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
      );
      PathPlannerPath path3 = PathPlannerPath(
        name: 'test2',
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
      );

      expect(path2, path1);
      expect(path3, isNot(path1));

      expect(path2.hashCode, isPositive);
      expect(path3.hashCode, isNot(path1.hashCode));
    });
  });

  test('add waypoint', () {
    PathPlannerPath path = PathPlannerPath(
      name: 'test',
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
    PathPlannerPath path = PathPlannerPath(
      name: 'test',
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
          command: const NoneCommand(),
        ),
      ],
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
  });
}
