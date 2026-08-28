import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/simulation/path2_path_follower.dart';
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/simulation/swerve_math.dart';
import 'package:pathplanner/path2/simulation/swerve_setpoint_generator.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

/// One root-to-leaf traversal used by the editor preview.
class Path2SimulationPathSnapshot {
  final String name;
  final List<String> nodeIds;
  final List<String> branchIds;
  final List<Path2SimulationWaypoint> waypoints;
  final double endToleranceMeters;
  final double endAngleToleranceRadians;

  Path2SimulationPathSnapshot({
    required this.name,
    required List<String> nodeIds,
    required List<String> branchIds,
    required List<Path2SimulationWaypoint> waypoints,
    required this.endToleranceMeters,
    required this.endAngleToleranceRadians,
  }) : nodeIds = List.unmodifiable(nodeIds),
       branchIds = List.unmodifiable(branchIds),
       waypoints = List.unmodifiable(waypoints);

  factory Path2SimulationPathSnapshot.fromMap(Map<String, dynamic> map) {
    return Path2SimulationPathSnapshot(
      name: map['name'] as String,
      nodeIds: List<String>.from(map['nodeIds'] as List<dynamic>),
      branchIds: List<String>.from(map['branchIds'] as List<dynamic>),
      waypoints: (map['waypoints'] as List<dynamic>)
          .map(
            (waypoint) => Path2SimulationWaypoint.fromMap(
              Map<String, dynamic>.from(waypoint as Map),
            ),
          )
          .toList(growable: false),
      endToleranceMeters: (map['endToleranceMeters'] as num).toDouble(),
      endAngleToleranceRadians: (map['endAngleToleranceRadians'] as num)
          .toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'nodeIds': nodeIds,
    'branchIds': branchIds,
    'waypoints': waypoints
        .map((waypoint) => waypoint.toMap())
        .toList(growable: false),
    'endToleranceMeters': endToleranceMeters,
    'endAngleToleranceRadians': endAngleToleranceRadians,
  };
}

/// A simulated traversal paired with the graph IDs that produced it.
class Path2SimulatedTraversal {
  final Path2SimulationPathSnapshot path;
  final Path2SimulationResult simulation;

  const Path2SimulatedTraversal({required this.path, required this.simulation});

  factory Path2SimulatedTraversal.fromMap(Map<String, dynamic> map) {
    return Path2SimulatedTraversal(
      path: Path2SimulationPathSnapshot.fromMap(
        Map<String, dynamic>.from(map['path'] as Map),
      ),
      simulation: Path2SimulationResult.fromMap(
        Map<String, dynamic>.from(map['simulation'] as Map),
      ),
    );
  }

  String get leafNodeId => path.nodeIds.last;

  Map<String, dynamic> toMap() => {
    'path': path.toMap(),
    'simulation': simulation.toMap(),
  };
}

/// All simulations that begin together for a Path 2 graph.
class Path2GraphSimulationResult {
  final List<Path2SimulatedTraversal> simulatedTraversals;

  Path2GraphSimulationResult(
    Iterable<Path2SimulatedTraversal> simulatedTraversals,
  ) : simulatedTraversals = List.unmodifiable(simulatedTraversals) {
    if (this.simulatedTraversals.isEmpty) {
      throw ArgumentError('A graph simulation requires at least one traversal');
    }
  }

  factory Path2GraphSimulationResult.fromMap(Map<String, dynamic> map) {
    return Path2GraphSimulationResult(
      (map['traversals'] as List<dynamic>).map(
        (result) => Path2SimulatedTraversal.fromMap(
          Map<String, dynamic>.from(result as Map),
        ),
      ),
    );
  }

  List<Path2SimulationResult> get traversals => List.unmodifiable(
    simulatedTraversals.map((traversal) => traversal.simulation),
  );

  Map<String, List<double>> get runtimesByLeafNodeId {
    final runtimes = <String, List<double>>{};
    for (final traversal in simulatedTraversals) {
      runtimes
          .putIfAbsent(traversal.leafNodeId, () => [])
          .add(traversal.simulation.totalTimeSeconds);
    }
    return Map.unmodifiable({
      for (final entry in runtimes.entries)
        entry.key: List<double>.unmodifiable(entry.value..sort()),
    });
  }

  double get totalTimeSeconds => simulatedTraversals.fold(
    0.0,
    (longest, traversal) =>
        math.max(longest, traversal.simulation.totalTimeSeconds),
  );

  Map<String, dynamic> toMap() => {
    'traversals': simulatedTraversals
        .map((result) => result.toMap())
        .toList(growable: false),
  };
}

/// A non-throwing result envelope suitable for a Flutter isolate boundary.
class Path2SimulationOutcome {
  final Path2GraphSimulationResult? result;
  final Path2SimulationFailure? failure;

  const Path2SimulationOutcome._({this.result, this.failure});

  const Path2SimulationOutcome.success(Path2GraphSimulationResult result)
    : this._(result: result);

  const Path2SimulationOutcome.failed(Path2SimulationFailure failure)
    : this._(failure: failure);

  factory Path2SimulationOutcome.fromMap(Map<String, dynamic> map) {
    final resultMap = map['result'];
    if (resultMap is Map) {
      return Path2SimulationOutcome.success(
        Path2GraphSimulationResult.fromMap(
          Map<String, dynamic>.from(resultMap),
        ),
      );
    }
    final failureMap = Map<String, dynamic>.from(map['failure'] as Map);
    return Path2SimulationOutcome.failed(
      Path2SimulationFailure(
        Path2SimulationFailureKind.values.byName(failureMap['kind'] as String),
        failureMap['message'] as String,
      ),
    );
  }

  bool get isSuccess => result != null;

  Map<String, dynamic> toMap() {
    final successfulResult = result;
    if (successfulResult != null) {
      return {'result': successfulResult.toMap()};
    }
    return {
      'failure': {'kind': failure!.kind.name, 'message': failure!.message},
    };
  }
}

/// Deterministic Path 2 graph simulation.
abstract final class Path2Simulator {
  static const double periodSeconds = 0.02;
  static const int maximumStepsPerPath = 6000;
  static const int stalledStepLimit = 250;

  /// Enumerates every unique branch traversal from the single graph root to a
  /// leaf. Condition transitions use their configured preview distance.
  static List<Path2SimulationPathSnapshot> previewTraversals(path2.Path path) {
    path.synchronizeInheritedTargets();
    final roots = path.rootNodes;
    if (roots.length != 1) {
      return const [];
    }

    final outgoing = <String, List<path2.PathBranch>>{};
    for (final branch in path.branches) {
      outgoing.putIfAbsent(branch.sourceId, () => []).add(branch);
    }
    final traversals = <Path2SimulationPathSnapshot>[];

    void visit(
      path2.PathNode node,
      List<path2.PathNode> nodes,
      List<path2.PathBranch> branches,
    ) {
      final allOutgoing = outgoing[node.id] ?? const [];
      if (allOutgoing.isEmpty) {
        traversals.add(_snapshotForTraversal(path, nodes, branches));
        return;
      }
      for (final branch in allOutgoing) {
        final target = path.nodeById(branch.targetId);
        if (target == null) {
          continue;
        }
        visit(target, [...nodes, target], [...branches, branch]);
      }
    }

    final root = roots.single;
    visit(root, [root], const []);
    return List.unmodifiable(traversals);
  }

  /// Kept as a source-compatible alias for callers of the first graph-preview
  /// implementation. It now includes condition branches as well.
  static List<Path2SimulationPathSnapshot> distanceTraversals(
    path2.Path path,
  ) => previewTraversals(path);

  static Future<Path2SimulationOutcome> simulatePathInBackground(
    path2.Path path,
    RobotConfig robotConfig,
  ) async {
    try {
      final traversals = previewTraversals(path);
      if (traversals.isEmpty) {
        return const Path2SimulationOutcome.failed(
          Path2SimulationFailure(
            Path2SimulationFailureKind.invalidPath,
            'No complete root-to-leaf traversal can be previewed.',
          ),
        );
      }
      final request = <String, dynamic>{
        'traversals': traversals
            .map((path) => path.toMap())
            .toList(growable: false),
        'config': Path2RobotConfigSnapshot.fromRobotConfig(robotConfig).toMap(),
      };
      return Path2SimulationOutcome.fromMap(
        await compute(_runPath2SimulationRequest, request),
      );
    } on Path2SimulationFailure catch (failure) {
      return Path2SimulationOutcome.failed(failure);
    } catch (error) {
      return Path2SimulationOutcome.failed(
        Path2SimulationFailure(
          Path2SimulationFailureKind.invalidConfiguration,
          error.toString(),
        ),
      );
    }
  }

  static Path2SimulationOutcome simulateTraversals(
    List<Path2SimulationPathSnapshot> traversals,
    Path2RobotConfigSnapshot robotConfig,
  ) {
    if (traversals.isEmpty) {
      return const Path2SimulationOutcome.failed(
        Path2SimulationFailure(
          Path2SimulationFailureKind.invalidPath,
          'At least one preview traversal is required for simulation.',
        ),
      );
    }

    final successfulResults = <Path2SimulatedTraversal>[];
    Path2SimulationFailure? firstFailure;
    for (final traversal in traversals) {
      try {
        _validatePath(traversal);
        successfulResults.add(
          Path2SimulatedTraversal(
            path: traversal,
            simulation: _simulateSinglePath(
              traversal,
              robotConfig,
              _standaloneInitialState(traversal),
            ),
          ),
        );
      } on Path2SimulationFailure catch (failure) {
        firstFailure ??= failure;
      } catch (error) {
        firstFailure ??= Path2SimulationFailure(
          Path2SimulationFailureKind.invalidConfiguration,
          error.toString(),
        );
      }
    }
    if (successfulResults.isNotEmpty) {
      return Path2SimulationOutcome.success(
        Path2GraphSimulationResult(successfulResults),
      );
    }
    return Path2SimulationOutcome.failed(
      firstFailure ??
          const Path2SimulationFailure(
            Path2SimulationFailureKind.invalidPath,
            'No preview traversal could be simulated.',
          ),
    );
  }

  static Path2SimulationPathSnapshot _snapshotForTraversal(
    path2.Path path,
    List<path2.PathNode> nodes,
    List<path2.PathBranch> branches,
  ) {
    final leaf = nodes.last;
    return Path2SimulationPathSnapshot(
      name: path.name,
      nodeIds: [for (final node in nodes) node.id],
      branchIds: [for (final branch in branches) branch.id],
      waypoints: [
        for (var index = 0; index < nodes.length; index++)
          Path2SimulationWaypoint.fromWaypoint(
            nodes[index].waypoint,
            handoffDistance: index < branches.length
                ? _previewDistance(branches[index].transition)
                : 0,
          ),
      ],
      endToleranceMeters: leaf.endTolerance.distanceMeters.toDouble(),
      endAngleToleranceRadians:
          leaf.endTolerance.angleDegrees.toDouble() * math.pi / 180,
    );
  }

  static num _previewDistance(PathTransition transition) {
    return switch (transition) {
      DistanceTransition(:final distanceMeters) => distanceMeters,
      ConditionTransition(:final previewDistanceMeters) =>
        previewDistanceMeters,
    };
  }

  static Path2SimulationResult _simulateSinglePath(
    Path2SimulationPathSnapshot path,
    Path2RobotConfigSnapshot robotConfig,
    Path2SimulationState initialState,
  ) {
    final follower = Path2PathFollower(
      waypoints: path.waypoints,
      endToleranceMeters: path.endToleranceMeters,
      endAngleToleranceRadians: path.endAngleToleranceRadians,
      initialPose: initialState.pose,
      initialRobotRelativeSpeeds: initialState.robotRelativeSpeeds,
      targetFirstWaypoint: false,
    );
    final generator = SwerveSetpointGenerator(robotConfig);
    var setpoint = Path2SwerveSetpoint.fromSimulationState(initialState);
    var currentState = initialState;
    var lastProgressState = initialState;
    var stalledSteps = 0;
    final samples = <Path2SimulationSample>[
      Path2SimulationSample(timeSeconds: 0, state: initialState),
    ];

    for (var step = 1; step <= maximumStepsPerPath; step++) {
      final desiredSpeeds = follower.calculate(
        currentState.pose,
        currentState.robotRelativeSpeeds,
      );
      setpoint = generator.generateSetpoint(setpoint, desiredSpeeds);
      currentState = Path2SimulationState(
        pose: Path2SimulationMath.integratePose(
          currentState.pose,
          setpoint.robotRelativeSpeeds,
          periodSeconds,
        ),
        robotRelativeSpeeds: setpoint.robotRelativeSpeeds,
        moduleStates: setpoint.moduleStates,
      );
      _validateState(currentState);
      samples.add(
        Path2SimulationSample(
          timeSeconds: step * periodSeconds,
          state: currentState,
        ),
      );

      if (_madePhysicalProgress(lastProgressState, currentState)) {
        lastProgressState = currentState;
        stalledSteps = 0;
      } else {
        stalledSteps++;
      }

      if (follower.isFinished) {
        return Path2SimulationResult(samples);
      }
      if (stalledSteps >= stalledStepLimit) {
        throw Path2SimulationFailure(
          Path2SimulationFailureKind.stalled,
          'Simulation of "${path.name}" stopped making progress.',
        );
      }
    }

    throw Path2SimulationFailure(
      Path2SimulationFailureKind.timedOut,
      'Simulation of "${path.name}" exceeded 120 seconds.',
    );
  }

  static Path2SimulationState _standaloneInitialState(
    Path2SimulationPathSnapshot path,
  ) {
    final first = path.waypoints.first;
    return Path2SimulationState.atRest(
      Pose2d(first.position, first.rotation ?? const Rotation2d()),
    );
  }

  static bool _madePhysicalProgress(
    Path2SimulationState previous,
    Path2SimulationState current,
  ) {
    if (previous.pose.translation.getDistance(current.pose.translation) >
            1e-5 ||
        (current.pose.rotation - previous.pose.rotation).radians.abs() > 1e-5 ||
        (current.robotRelativeSpeeds.vx - previous.robotRelativeSpeeds.vx)
                .abs() >
            1e-5 ||
        (current.robotRelativeSpeeds.vy - previous.robotRelativeSpeeds.vy)
                .abs() >
            1e-5 ||
        (current.robotRelativeSpeeds.omega - previous.robotRelativeSpeeds.omega)
                .abs() >
            1e-5) {
      return true;
    }
    for (var index = 0; index < current.moduleStates.length; index++) {
      final before = previous.moduleStates[index];
      final after = current.moduleStates[index];
      if ((after.speedMetersPerSecond - before.speedMetersPerSecond).abs() >
              1e-5 ||
          (after.angle - before.angle).radians.abs() > 1e-5) {
        return true;
      }
    }
    return false;
  }

  static void _validatePath(Path2SimulationPathSnapshot path) {
    if (path.waypoints.isEmpty ||
        path.nodeIds.length != path.waypoints.length ||
        path.branchIds.length != path.waypoints.length - 1) {
      throw Path2SimulationFailure(
        Path2SimulationFailureKind.invalidPath,
        'Path "${path.name}" has an invalid traversal.',
      );
    }
    if (!path.endToleranceMeters.isFinite ||
        path.endToleranceMeters < 0 ||
        !path.endAngleToleranceRadians.isFinite ||
        path.endAngleToleranceRadians < 0) {
      throw Path2SimulationFailure(
        Path2SimulationFailureKind.invalidPath,
        'Path "${path.name}" has invalid end tolerances.',
      );
    }
    for (final waypoint in path.waypoints) {
      if (!waypoint.position.x.toDouble().isFinite ||
          !waypoint.position.y.toDouble().isFinite ||
          !(waypoint.rotation?.radians.toDouble().isFinite ?? true) ||
          !(waypoint.pointTowardsTarget?.x.toDouble().isFinite ?? true) ||
          !(waypoint.pointTowardsTarget?.y.toDouble().isFinite ?? true) ||
          !waypoint.maxVelocity.isFinite ||
          waypoint.maxVelocity < 0 ||
          !waypoint.handoffDistance.isFinite ||
          waypoint.handoffDistance < 0 ||
          !waypoint.maxAngularVelocityRadiansPerSecond.isFinite ||
          waypoint.maxAngularVelocityRadiansPerSecond <= 0 ||
          !waypoint.maxAngularAccelerationRadiansPerSecondSquared.isFinite ||
          waypoint.maxAngularAccelerationRadiansPerSecondSquared <= 0) {
        throw Path2SimulationFailure(
          Path2SimulationFailureKind.invalidPath,
          'Path "${path.name}" contains invalid waypoint values.',
        );
      }
    }
  }

  static void _validateState(Path2SimulationState state) {
    if (!Path2SimulationMath.isFinitePose(state.pose) ||
        !Path2SimulationMath.isFiniteChassisSpeeds(state.robotRelativeSpeeds) ||
        state.moduleStates.any(
          (module) =>
              !module.speedMetersPerSecond.isFinite ||
              !module.angle.radians.toDouble().isFinite,
        )) {
      throw const Path2SimulationFailure(
        Path2SimulationFailureKind.nonFiniteState,
        'The simulated robot state became non-finite.',
      );
    }
  }
}

Map<String, dynamic> _runPath2SimulationRequest(Map<String, dynamic> request) {
  try {
    final traversals = (request['traversals'] as List<dynamic>)
        .map(
          (path) => Path2SimulationPathSnapshot.fromMap(
            Map<String, dynamic>.from(path as Map),
          ),
        )
        .toList(growable: false);
    final config = Path2RobotConfigSnapshot.fromMap(
      Map<String, dynamic>.from(request['config'] as Map),
    );
    return Path2Simulator.simulateTraversals(traversals, config).toMap();
  } on Path2SimulationFailure catch (failure) {
    return Path2SimulationOutcome.failed(failure).toMap();
  } catch (error) {
    return Path2SimulationOutcome.failed(
      Path2SimulationFailure(
        Path2SimulationFailureKind.invalidConfiguration,
        error.toString(),
      ),
    ).toMap();
  }
}
