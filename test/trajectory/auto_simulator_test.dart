import 'dart:math';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/trajectory/auto_simulator.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/motor_torque_curve.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
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
      idealStartingState: IdealStartingState(),
      useDefaultConstraints: false,
    );

    PathPlannerPath test2 = PathPlannerPath(
      name: '',
      waypoints: [
        Waypoint(
          anchor: const Point(7, 3),
          nextControl: const Point(9, 3),
        ),
        Waypoint(
          prevControl: const Point(10, 5),
          anchor: const Point(12, 5),
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
      idealStartingState: IdealStartingState(),
      useDefaultConstraints: false,
    );

    var config = RobotConfig(
      massKG: 70.0,
      moi: 6.8,
      moduleConfig: const ModuleConfig(
        wheelRadiusMeters: 0.048,
        driveGearing: 5.12,
        maxDriveVelocityRPM: 5600,
        driveMotorTorqueCurve: MotorTorqueCurve.kraken60A,
        wheelCOF: 1.2,
      ),
      moduleLocations: const [
        Translation2d(x: 0.25, y: 0.25),
        Translation2d(x: 0.25, y: -0.25),
        Translation2d(x: -0.25, y: 0.25),
        Translation2d(x: -0.25, y: -0.25),
      ],
      holonomic: true,
    );

    // Basic coverage tests, expand in future
    PathPlannerTrajectory? sim = AutoSimulator.simulateAuto([], config);
    expect(sim, isNull);

    sim = AutoSimulator.simulateAuto([test], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(2.87, 0.05));

    sim = AutoSimulator.simulateAuto([test2], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(2.87, 0.05));

    sim = AutoSimulator.simulateAuto([test, test2], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(5.78, 0.05));
  });
}
