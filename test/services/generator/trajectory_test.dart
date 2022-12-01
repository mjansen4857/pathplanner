import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/stop_event.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/generator/trajectory.dart';

void main() {
  group('Generate trajectory', () {
    // Trajectory is a pretty complex class, so just check that the runtime of
    // the path is correct to make sure something isn't very wrong
    test('simple path', () async {
      List<Waypoint> waypoints = [
        Waypoint(
          anchorPoint: const Point(1.0, 3.0),
          nextControl: const Point(2.0, 3.0),
          stopEvent: StopEvent(
            eventNames: [],
          ),
        ),
        Waypoint(
          prevControl: const Point(3.0, 4.0),
          anchorPoint: const Point(3.0, 5.0),
          stopEvent: StopEvent(
            eventNames: [],
          ),
        ),
      ];
      RobotPath path =
          RobotPath(waypoints: waypoints, maxVelocity: 8, maxAcceleration: 5);

      Trajectory traj = await Trajectory.generateFullTrajectory(path);

      expect(traj.getRuntime(), closeTo(1.585, 0.001));
    });

    test('complex path', () async {
      List<Waypoint> waypoints = [
        Waypoint(
          anchorPoint: const Point(1.0, 3.0),
          nextControl: const Point(2.0, 3.0),
          stopEvent: StopEvent(
            eventNames: [],
          ),
        ),
        Waypoint(
          prevControl: const Point(3.0, 4.0),
          anchorPoint: const Point(3.0, 5.0),
          stopEvent: StopEvent(
            eventNames: [],
          ),
          isReversal: true,
        ),
        Waypoint(
          prevControl: const Point(4.0, 3.0),
          anchorPoint: const Point(5.0, 3.0),
          stopEvent: StopEvent(
            eventNames: [],
          ),
        ),
      ];
      RobotPath path =
          RobotPath(waypoints: waypoints, maxVelocity: 8, maxAcceleration: 5);

      Trajectory traj = await Trajectory.generateFullTrajectory(path);

      expect(traj.getRuntime(), closeTo(3.171, 0.001));
    });
  });
}
