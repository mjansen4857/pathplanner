import 'dart:math' as math;

import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/simulation/path2_path_follower.dart';
import 'package:pathplanner/path2/simulation/path2_simulator.dart';
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  late Path2RobotConfigSnapshot robotConfig;

  setUp(() {
    robotConfig = Path2RobotConfigSnapshot.fromRobotConfig(
      RobotConfig(
        massKG: 74,
        moi: 6.8,
        bumperSize: const Size(0.9, 0.9),
        bumperOffset: const Translation2d(),
        moduleConfig: ModuleConfig(
          wheelRadiusMeters: 0.048,
          maxDriveVelocityMPS: 5,
          driveMotor: DCMotor.getKrakenX60(1).withReduction(5.14),
          driveCurrentLimit: 60,
          wheelCOF: 1.2,
        ),
        moduleLocations: const [
          Translation2d(0.273, 0.273),
          Translation2d(0.273, -0.273),
          Translation2d(-0.273, 0.273),
          Translation2d(-0.273, -0.273),
        ],
        holonomic: true,
      ),
    );
  });

  path2.PathNode node(double x, double y, {bool pose = true}) {
    return path2.PathNode(
      waypoint: pose
          ? PoseWaypoint(
              position: Translation2d(x, y),
              rotation: const Rotation2d(),
            )
          : TranslationWaypoint(position: Translation2d(x, y)),
      editorPosition: Offset(x * 100, y * 100),
    );
  }

  path2.Path graph(
    List<path2.PathNode> nodes,
    List<path2.PathBranch> branches,
  ) {
    return path2.Path(
      name: 'Graph',
      nodes: nodes,
      branches: branches,
      fs: MemoryFileSystem(),
      pathDir: '/paths',
    );
  }

  test('enumerates every root-to-leaf preview traversal', () {
    final root = node(0, 0);
    final middle = node(1, 0, pose: false);
    final upper = node(2, 1);
    final lower = node(2, -1);
    final first = path2.PathBranch(
      sourceId: root.id,
      targetId: middle.id,
      transition: DistanceTransition(distanceMeters: 0.3),
    );
    final upperBranch = path2.PathBranch(
      sourceId: middle.id,
      targetId: upper.id,
      transition: DistanceTransition(distanceMeters: 0.4),
    );
    final lowerBranch = path2.PathBranch(
      sourceId: middle.id,
      targetId: lower.id,
      transition: DistanceTransition(distanceMeters: 0.5),
    );
    final path = graph(
      [root, middle, upper, lower],
      [first, upperBranch, lowerBranch],
    );

    final traversals = Path2Simulator.previewTraversals(path);

    expect(traversals, hasLength(2));
    expect(
      traversals.map((traversal) => traversal.nodeIds),
      containsAll([
        [root.id, middle.id, upper.id],
        [root.id, middle.id, lower.id],
      ]),
    );
    expect(
      traversals.map((traversal) => traversal.branchIds),
      containsAll([
        [first.id, upperBranch.id],
        [first.id, lowerBranch.id],
      ]),
    );
    for (final traversal in traversals) {
      // The outgoing transition from the middle waypoint controls when the
      // old follower hands off from that waypoint to its selected leaf.
      expect(traversal.waypoints[1].handoffDistance, anyOf(0.4, 0.5));
      expect(traversal.waypoints.last.handoffDistance, 0);
    }
  });

  test('condition branches use their preview distance', () {
    final root = node(0, 0);
    final distanceLeaf = node(2, 0);
    final conditionLeaf = node(2, 1);
    final path = graph(
      [root, distanceLeaf, conditionLeaf],
      [
        path2.PathBranch(
          sourceId: root.id,
          targetId: distanceLeaf.id,
          transition: DistanceTransition(),
        ),
        path2.PathBranch(
          sourceId: root.id,
          targetId: conditionLeaf.id,
          transition: ConditionTransition(
            conditionName: 'ready',
            previewDistanceMeters: 0.7,
          ),
        ),
      ],
    );

    final traversals = Path2Simulator.previewTraversals(path);

    expect(traversals, hasLength(2));
    final conditionTraversal = traversals.singleWhere(
      (traversal) => traversal.nodeIds.last == conditionLeaf.id,
    );
    expect(conditionTraversal.nodeIds, [root.id, conditionLeaf.id]);
    expect(conditionTraversal.waypoints.first.handoffDistance, 0.7);
  });

  test('parallel distance branches remain separate traversals', () {
    final root = node(0, 0);
    final leaf = node(2, 0);
    final near = path2.PathBranch(
      sourceId: root.id,
      targetId: leaf.id,
      transition: DistanceTransition(distanceMeters: 0.2),
    );
    final far = path2.PathBranch(
      sourceId: root.id,
      targetId: leaf.id,
      transition: DistanceTransition(distanceMeters: 0.8),
    );

    final traversals =
        Path2Simulator.previewTraversals(graph([root, leaf], [near, far]));

    expect(traversals, hasLength(2));
    expect(
      traversals.map((traversal) => traversal.branchIds.single),
      containsAll([near.id, far.id]),
    );
  });

  test('simulates all traversals from time zero and uses the longest duration',
      () {
    final short = Path2SimulationPathSnapshot(
      name: 'short',
      nodeIds: const ['one', 'two'],
      branchIds: const ['short-branch'],
      waypoints: [
        simulationWaypoint(0, 0, handoffDistance: 0.25),
        simulationWaypoint(1, 0, handoffDistance: 0),
      ],
      endToleranceMeters: 0.1,
      endAngleToleranceRadians: math.pi / 90,
    );
    final long = Path2SimulationPathSnapshot(
      name: 'long',
      nodeIds: const ['one', 'three'],
      branchIds: const ['long-branch'],
      waypoints: [
        simulationWaypoint(0, 0, handoffDistance: 0.25),
        simulationWaypoint(3, 0, handoffDistance: 0),
      ],
      endToleranceMeters: 0.1,
      endAngleToleranceRadians: math.pi / 90,
    );

    final outcome =
        Path2Simulator.simulateTraversals([short, long], robotConfig);

    expect(outcome.failure, isNull);
    expect(outcome.result!.traversals, hasLength(2));
    expect(
      outcome.result!.traversals
          .map((traversal) => traversal.samples.first.timeSeconds),
      everyElement(0),
    );
    expect(
      outcome.result!.totalTimeSeconds,
      outcome.result!.traversals
          .map((traversal) => traversal.totalTimeSeconds)
          .reduce(math.max),
    );
    expect(outcome.result!.runtimesByLeafNodeId.keys, {'two', 'three'});
    expect(outcome.result!.runtimesByLeafNodeId['two'], hasLength(1));
    expect(outcome.result!.runtimesByLeafNodeId['three'], hasLength(1));
    final restored = Path2SimulationOutcome.fromMap(outcome.toMap());
    expect(restored.result!.runtimesByLeafNodeId.keys, {'two', 'three'});
  });
}

Path2SimulationWaypoint simulationWaypoint(
  double x,
  double y, {
  required double handoffDistance,
}) {
  return Path2SimulationWaypoint(
    position: Translation2d(x, y),
    rotation: const Rotation2d(),
    maxVelocity: 3,
    handoffDistance: handoffDistance,
    maxAngularVelocityRadiansPerSecond: 2 * math.pi,
    maxAngularAccelerationRadiansPerSecondSquared: 4 * math.pi,
  );
}
