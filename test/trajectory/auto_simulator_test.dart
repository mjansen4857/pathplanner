import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/point_towards_zone.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/trajectory/auto_simulator.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  test('simulate auto', () {
    PathPlannerPath test = PathPlannerPath(
      name: '',
      waypoints: [
        Waypoint(
          anchor: const Translation2d(1, 1),
          nextControl: const Translation2d(3, 1),
        ),
        Waypoint(
          prevControl: const Translation2d(4, 3),
          anchor: const Translation2d(6, 3),
        ),
      ],
      globalConstraints: PathConstraints(),
      goalEndState: GoalEndState(0.0, const Rotation2d()),
      constraintZones: [
        ConstraintsZone(
            constraints: PathConstraints(),
            minWaypointRelativePos: 0.2,
            maxWaypointRelativePos: 0.4),
      ],
      pointTowardsZones: [PointTowardsZone()],
      rotationTargets: [
        RotationTarget(0.5, Rotation2d.fromDegrees(45)),
      ],
      eventMarkers: [],
      pathDir: '',
      fs: MemoryFileSystem(),
      reversed: false,
      folder: null,
      idealStartingState: IdealStartingState(0.0, const Rotation2d()),
      useDefaultConstraints: false,
    );

    PathPlannerPath test2 = PathPlannerPath(
      name: '',
      waypoints: [
        Waypoint(
          anchor: const Translation2d(7, 3),
          nextControl: const Translation2d(9, 3),
        ),
        Waypoint(
          prevControl: const Translation2d(10, 5),
          anchor: const Translation2d(12, 5),
        ),
      ],
      globalConstraints: PathConstraints(),
      goalEndState: GoalEndState(0.0, const Rotation2d()),
      constraintZones: [
        ConstraintsZone(
            constraints: PathConstraints(),
            minWaypointRelativePos: 0.2,
            maxWaypointRelativePos: 0.4),
      ],
      pointTowardsZones: [PointTowardsZone()],
      rotationTargets: [
        RotationTarget(0.5, Rotation2d.fromDegrees(45)),
      ],
      eventMarkers: [],
      pathDir: '',
      fs: MemoryFileSystem(),
      reversed: false,
      folder: null,
      idealStartingState: IdealStartingState(0.0, const Rotation2d()),
      useDefaultConstraints: false,
    );

    var config = RobotConfig(
      massKG: 70.0,
      moi: 6.8,
      moduleConfig: ModuleConfig(
        wheelRadiusMeters: 0.048,
        driveMotor: DCMotor.getKrakenX60(1).withReduction(5.12),
        driveCurrentLimit: 60,
        maxDriveVelocityMPS: 5.4,
        wheelCOF: 1.2,
      ),
      moduleLocations: const [
        Translation2d(0.25, 0.25),
        Translation2d(0.25, -0.25),
        Translation2d(-0.25, 0.25),
        Translation2d(-0.25, -0.25),
      ],
      holonomic: true,
    );

    // Basic coverage tests, expand in future
    PathPlannerTrajectory? sim = AutoSimulator.simulateAuto([], config);
    expect(sim, isNull);

    sim = AutoSimulator.simulateAuto([test], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(3.82, 0.05));

    sim = AutoSimulator.simulateAuto([test2], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(4.43, 0.05));

    sim = AutoSimulator.simulateAuto([test, test2], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(8.25, 0.05));
  });
}
