import 'dart:math' as math;

import 'package:file/memory.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:pathplanner/util/wpimath/kinematics.dart';

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

  test(
    'branch event markers use the first evaluation pose and survive transport',
    () {
      final root = node(0, 0);
      final leaf = node(3, 0);
      final branch = path2.PathBranch(
        sourceId: root.id,
        targetId: leaf.id,
        events: [
          path2.BranchEvent(name: 'Start', position: 0),
          path2.BranchEvent(name: 'Intake', position: 0.2),
          path2.BranchEvent(name: 'Intake', position: 0.2),
          path2.BranchEvent(name: 'End', position: 1),
        ],
      );
      final snapshots = Path2Simulator.previewTraversals(
        graph([root, leaf], [branch]),
      );
      final snapshot = Path2SimulationPathSnapshot.fromMap(
        snapshots.single.toMap(),
      );
      expect(snapshot.branchEvents.single, branch.events);
      final outcome = Path2Simulator.simulateTraversals([
        snapshot,
      ], robotConfig);
      expect(outcome.failure, isNull);
      final result = outcome.result!.traversals.single;
      final markers = result.branchEventMarkers;
      expect(markers.first.timeSeconds, 0);
      expect(markers.first.pose.translation, root.waypoint.position);
      final expected = result.samples.firstWhere(
        (sample) =>
            sample.pose.translation.getDistance(leaf.waypoint.position) / 3 <=
            0.8,
      );
      final intake = markers
          .where((marker) => marker.name == 'Intake')
          .toList();
      expect(intake, hasLength(2));
      expect(intake.map((marker) => marker.eventIndex), [1, 2]);
      for (final marker in intake) {
        expect(marker.timeSeconds, expected.timeSeconds);
        expect(marker.pose, expected.pose);
      }
      expect(markers.where((marker) => marker.name == 'End'), isEmpty);
      final restored = Path2SimulationOutcome.fromMap(outcome.toMap())
          .result!
          .traversals
          .single;
      expect(
        restored.branchEventMarkers.map((marker) => marker.toMap()).toList(),
        markers.map((marker) => marker.toMap()).toList(),
      );
    },
  );

  test(
    'curved traversals respect active branches and never force unmet events',
    () {
      final root = node(0, 0);
      final middle = node(2, 0, pose: false);
      final upper = node(3, 2);
      final lower = node(3, -2);
      final incoming = path2.PathBranch(
        sourceId: root.id,
        targetId: middle.id,
        events: [
          path2.BranchEvent(name: 'Early', position: 0.2),
          path2.BranchEvent(name: 'Unreached', position: 1),
        ],
      );
      final outgoing = [
        for (final leaf in [upper, lower])
          path2.PathBranch(
            sourceId: middle.id,
            targetId: leaf.id,
            transition: DistanceTransition(distanceMeters: 0.8),
            events: [path2.BranchEvent(name: 'Curve', position: 0.5)],
          ),
      ];
      final traversals = Path2Simulator.previewTraversals(
        graph([root, middle, upper, lower], [incoming, ...outgoing]),
      );
      final outcome = Path2Simulator.simulateTraversals(
        traversals,
        robotConfig,
      );
      expect(outcome.failure, isNull);
      expect(outcome.result!.traversals, hasLength(2));
      for (final traversal in outcome.result!.simulatedTraversals) {
        final markers = traversal.simulation.branchEventMarkers;
        expect(markers.where((m) => m.name == 'Early'), hasLength(1));
        expect(markers.where((m) => m.name == 'Unreached'), isEmpty);
        final curve = markers.singleWhere((m) => m.name == 'Curve');
        expect(curve.branchId, traversal.path.branchIds.last);
        final target = traversal.path.waypoints.last.position;
        final distance = middle.waypoint.position.getDistance(target);
        final expected = traversal.simulation.samples.firstWhere(
          (sample) =>
              sample.pose.translation.getDistance(target) / distance <= 0.5,
        );
        expect(curve.pose, expected.pose);
        expect(curve.timeSeconds, expected.timeSeconds);
      }
    },
  );

  test('coincident branch endpoints produce no event markers', () {
    final root = node(0, 0);
    final leaf = node(0, 0);
    final branch = path2.PathBranch(
      sourceId: root.id,
      targetId: leaf.id,
      events: [path2.BranchEvent(name: 'Undefined', position: 0)],
    );
    final outcome = Path2Simulator.simulateTraversals(
      Path2Simulator.previewTraversals(graph([root, leaf], [branch])),
      robotConfig,
    );
    expect(outcome.failure, isNull);
    expect(outcome.result!.traversals.single.branchEventMarkers, isEmpty);
  });

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

    final traversals = Path2Simulator.previewTraversals(
      graph([root, leaf], [near, far]),
    );

    expect(traversals, hasLength(2));
    expect(
      traversals.map((traversal) => traversal.branchIds.single),
      containsAll([near.id, far.id]),
    );
  });

  test(
    'traversal snapshots contain resolved point targets and controller mode',
    () {
      final parent = path2.PathNode(
        waypoint: PointTowardsWaypoint(
          position: const Translation2d(),
          targetPosition: const Translation2d(3, -2),
        ),
        editorPosition: Offset.zero,
      );
      final child = path2.PathNode(
        waypoint: PointTowardsWaypoint(
          position: const Translation2d(1, 0),
          inheritTargetFromParent: true,
          rotationOffset: Rotation2d.fromDegrees(35),
          unprofiled: true,
        ),
        editorPosition: const Offset(0, 200),
      );
      final traversal = Path2Simulator.previewTraversals(
        graph(
          [parent, child],
          [path2.PathBranch(sourceId: parent.id, targetId: child.id)],
        ),
      ).single;

      expect(
        traversal.waypoints.last.pointTowardsTarget,
        const Translation2d(3, -2),
      );
      expect(traversal.waypoints.last.unprofiled, isTrue);
      expect(
        traversal.waypoints.last.pointTowardsRotationOffset.degrees,
        closeTo(35, 0.001),
      );
      final restored = Path2SimulationPathSnapshot.fromMap(traversal.toMap());
      expect(
        restored.waypoints.last.pointTowardsTarget,
        const Translation2d(3, -2),
      );
      expect(restored.waypoints.last.unprofiled, isTrue);
      expect(
        restored.waypoints.last.pointTowardsRotationOffset.degrees,
        closeTo(35, 0.001),
      );
    },
  );

  test('active point target dynamically overrides future pose lookahead', () {
    double omegaAt(double robotY) {
      final currentPose = Pose2d(Translation2d(0, robotY), const Rotation2d());
      final follower = Path2PathFollower(
        waypoints: [
          simulationWaypoint(0, robotY, handoffDistance: 0.2),
          simulationWaypoint(
            2,
            robotY,
            handoffDistance: 0.2,
            rotation: null,
            pointTowardsTarget: const Translation2d(),
          ),
          simulationWaypoint(
            3,
            robotY,
            handoffDistance: 0,
            rotation: Rotation2d.fromDegrees(90),
          ),
        ],
        endToleranceMeters: 0.1,
        endAngleToleranceRadians: math.pi / 90,
        initialPose: currentPose,
        initialRobotRelativeSpeeds: const ChassisSpeeds(),
        targetFirstWaypoint: false,
      );
      return follower.calculate(currentPose).omega.toDouble();
    }

    expect(omegaAt(-1), greaterThan(0));
    expect(
      omegaAt(1),
      lessThan(0),
      reason: 'the active point target must override the future +90° pose',
    );
  });

  test('coincident point target falls back to the current heading', () {
    final currentPose = Pose2d(
      const Translation2d(),
      Rotation2d.fromRadians(0.7),
    );
    final follower = Path2PathFollower(
      waypoints: [
        simulationWaypoint(-1, 0, handoffDistance: 0.2),
        simulationWaypoint(
          1,
          0,
          handoffDistance: 0,
          rotation: null,
          pointTowardsTarget: const Translation2d(),
          pointTowardsRotationOffset: Rotation2d.fromDegrees(90),
        ),
      ],
      endToleranceMeters: 0.1,
      endAngleToleranceRadians: math.pi / 90,
      initialPose: currentPose,
      initialRobotRelativeSpeeds: const ChassisSpeeds(),
      targetFirstWaypoint: false,
    );

    expect(follower.calculate(currentPose).omega, closeTo(0, 1e-12));
  });

  test('point target rotation offset is added to the dynamic heading', () {
    const currentPose = Pose2d(Translation2d(), Rotation2d());
    final follower = Path2PathFollower(
      waypoints: [
        simulationWaypoint(-1, 0, handoffDistance: 0.2),
        simulationWaypoint(
          1,
          0,
          handoffDistance: 0,
          rotation: null,
          pointTowardsTarget: const Translation2d(2, 0),
          pointTowardsRotationOffset: Rotation2d.fromDegrees(90),
        ),
      ],
      endToleranceMeters: 0.1,
      endAngleToleranceRadians: math.pi / 90,
      initialPose: currentPose,
      initialRobotRelativeSpeeds: const ChassisSpeeds(),
      targetFirstWaypoint: false,
    );

    expect(follower.calculate(currentPose).omega, greaterThan(0));
  });

  test('unprofiled point target uses direct PID output', () {
    double firstOmega(bool unprofiled) {
      const currentPose = Pose2d(Translation2d(), Rotation2d());
      final follower = Path2PathFollower(
        waypoints: [
          simulationWaypoint(-1, 0, handoffDistance: 0.2),
          simulationWaypoint(
            1,
            0,
            handoffDistance: 0,
            rotation: null,
            pointTowardsTarget: const Translation2d(0, 1),
            unprofiled: unprofiled,
            maxAngularAcceleration: 1,
          ),
        ],
        endToleranceMeters: 0.1,
        endAngleToleranceRadians: math.pi / 90,
        initialPose: currentPose,
        initialRobotRelativeSpeeds: const ChassisSpeeds(),
        targetFirstWaypoint: false,
      );
      return follower.calculate(currentPose).omega.toDouble();
    }

    final profiled = firstOmega(false);
    final unprofiled = firstOmega(true);
    expect(profiled, greaterThan(0));
    expect(unprofiled, greaterThan(profiled * 100));
  });

  test('returning to profiled rotation resets its prior controller state', () {
    const currentPose = Pose2d(Translation2d(), Rotation2d());
    final follower = Path2PathFollower(
      waypoints: [
        simulationWaypoint(0, 0, handoffDistance: 0.2),
        simulationWaypoint(
          1,
          0,
          handoffDistance: 0.2,
          rotation: null,
          pointTowardsTarget: const Translation2d(0, 2),
        ),
        simulationWaypoint(
          2,
          0,
          handoffDistance: 0.2,
          rotation: null,
          pointTowardsTarget: const Translation2d(0, -2),
          unprofiled: true,
        ),
        simulationWaypoint(
          3,
          0,
          handoffDistance: 0,
          rotation: const Rotation2d(),
        ),
      ],
      endToleranceMeters: 0.1,
      endAngleToleranceRadians: math.pi / 90,
      initialPose: currentPose,
      initialRobotRelativeSpeeds: const ChassisSpeeds(),
      targetFirstWaypoint: false,
    );
    for (var i = 0; i < 20; i++) {
      follower.calculate(currentPose);
    }
    follower.calculate(const Pose2d(Translation2d(0.9, 0), Rotation2d()));
    expect(follower.targetWaypointIndex, 2);

    final output = follower.calculate(
      const Pose2d(Translation2d(1.9, 0), Rotation2d()),
    );
    expect(follower.targetWaypointIndex, 3);
    expect(output.omega, closeTo(0, 1e-12));
  });

  test('completion uses the active unprofiled controller tolerance', () {
    final follower = Path2PathFollower(
      waypoints: [
        simulationWaypoint(
          0,
          0,
          handoffDistance: 0,
          rotation: null,
          pointTowardsTarget: const Translation2d(0, 1),
          unprofiled: true,
        ),
      ],
      endToleranceMeters: 0.1,
      endAngleToleranceRadians: math.pi / 90,
      initialPose: const Pose2d(Translation2d(), Rotation2d()),
      initialRobotRelativeSpeeds: const ChassisSpeeds(),
      targetFirstWaypoint: true,
    );

    follower.calculate(const Pose2d(Translation2d(), Rotation2d()));
    expect(follower.isFinished, isFalse);
    follower.calculate(
      Pose2d(const Translation2d(), Rotation2d.fromDegrees(90)),
    );
    expect(follower.isFinished, isTrue);
  });

  test(
    'simulates all traversals from time zero and uses the longest duration',
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

      final outcome = Path2Simulator.simulateTraversals([
        short,
        long,
      ], robotConfig);

      expect(outcome.failure, isNull);
      expect(outcome.result!.traversals, hasLength(2));
      expect(
        outcome.result!.traversals.map(
          (traversal) => traversal.samples.first.timeSeconds,
        ),
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
    },
  );
}

Path2SimulationWaypoint simulationWaypoint(
  double x,
  double y, {
  required double handoffDistance,
  Rotation2d? rotation = const Rotation2d(),
  Translation2d? pointTowardsTarget,
  Rotation2d pointTowardsRotationOffset = const Rotation2d(),
  bool unprofiled = false,
  double maxAngularAcceleration = 4 * math.pi,
}) {
  return Path2SimulationWaypoint(
    position: Translation2d(x, y),
    rotation: rotation,
    pointTowardsTarget: pointTowardsTarget,
    pointTowardsRotationOffset: pointTowardsRotationOffset,
    unprofiled: unprofiled,
    maxVelocity: 3,
    handoffDistance: handoffDistance,
    maxAngularVelocityRadiansPerSecond: 2 * math.pi,
    maxAngularAccelerationRadiansPerSecondSquared: maxAngularAcceleration,
  );
}
