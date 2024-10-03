import 'dart:ui';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/path_optimizer.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('path optimizer', () async {
    // Simple test. Due to the randomness of the optimizer its hard to
    // do any more definitive testing than just making sure it takes less time

    SharedPreferences.setMockInitialValues({});
    SharedPreferences prefs = await SharedPreferences.getInstance();

    PathPlannerPath unoptimized = PathPlannerPath(
      name: 'unoptimized',
      waypoints: [
        Waypoint(
          anchor: const Translation2d(1.0, 1.0),
          nextControl: const Translation2d(3.0, 1.0),
        ),
        Waypoint(
          prevControl: const Translation2d(5.0, 3.0),
          anchor: const Translation2d(7.0, 3.0),
        ),
      ],
      globalConstraints: PathConstraints(),
      goalEndState: GoalEndState(0.0, const Rotation2d()),
      constraintZones: [],
      pointTowardsZones: [],
      rotationTargets: [],
      eventMarkers: [],
      pathDir: '',
      fs: MemoryFileSystem(),
      reversed: false,
      folder: null,
      idealStartingState: IdealStartingState(0.0, const Rotation2d()),
      useDefaultConstraints: false,
    );

    RobotConfig config = RobotConfig.fromPrefs(prefs);
    num originalTime =
        PathPlannerTrajectory(path: unoptimized, robotConfig: config)
            .getTotalTimeSeconds();

    const fieldSize = Size(16.54, 8.21);
    const robotSize = Size(0.9, 0.9);

    final result = await PathOptimizer.optimizePath(
        unoptimized, config, fieldSize, robotSize);
    expect(result.runtime, isNonNegative);
    expect(result.runtime, isNotNaN);
    expect(result.runtime, lessThan(originalTime));
  });
}
