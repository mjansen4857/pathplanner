import 'dart:math';
import 'dart:ui';

import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

class PathOptimizer {
  static const int populationSize = 50;
  static const int generations = 100;

  static IsolateManager? _manager;

  static Future<OptimizationResult> optimizePath(PathPlannerPath path,
      RobotConfig config, Size fieldSizeMeters, Size robotSizeMeters,
      {ValueChanged<OptimizationResult>? onUpdate}) async {
    // Create a new path in the memory file system so it can't edit any original paths or files
    PathPlannerPath copy = PathPlannerPath(
      name: path.name,
      waypoints: PathPlannerPath.cloneWaypoints(path.waypoints),
      globalConstraints: path.globalConstraints.clone(),
      goalEndState: path.goalEndState.clone(),
      constraintZones:
          PathPlannerPath.cloneConstraintZones(path.constraintZones),
      rotationTargets:
          PathPlannerPath.cloneRotationTargets(path.rotationTargets),
      pointTowardsZones:
          PathPlannerPath.clonePointTowardsZones(path.pointTowardsZones),
      eventMarkers: [], // Markers don't matter. Save some memory
      pathDir: '',
      fs: MemoryFileSystem(),
      reversed: path.reversed,
      folder: '',
      idealStartingState: path.idealStartingState.clone(),
      useDefaultConstraints: path.useDefaultConstraints,
    );

    _manager ??= IsolateManager.createCustom(_optimizePathWaypoints);

    Log.info('Optimizing path: ${path.name}');

    final start = DateTime.now();
    final OptimizationResult result = await _manager!.compute(
      _OptimizerArgs(copy, config, fieldSizeMeters, robotSizeMeters),
      callback: (value) {
        OptimizationResult result = value;
        Log.info(
            'Best fit after generation ${result.generation}: ${result.runtime.toStringAsFixed(2)}s');
        onUpdate?.call(result);

        return result.generation == generations;
      },
    );
    final runtime = DateTime.now().difference(start);
    Log.info(
        'Finished ${PathOptimizer.generations} generations in ${(runtime.inMilliseconds / 1000.0).toStringAsFixed(2)}s');
    return result;
  }

  @isolateManagerCustomWorker
  static void _optimizePathWaypoints(dynamic params) {
    IsolateManagerFunction.customFunction<OptimizationResult, _OptimizerArgs>(
      params,
      onEvent: (controller, args) async {
        var rand = Random();

        // Check if any of the waypoints would cause the robot to go outside
        // of the field. If not, make sure all optimization results are
        // inside of the field perimiter to be considered valid.
        bool preventFieldExit = true;
        final num robotRadius = sqrt(pow(args.robotSizeMeters.width / 2.0, 2) +
            pow(args.robotSizeMeters.height / 2.0, 2));
        final minPos = Translation2d(robotRadius, robotRadius);
        final maxPos = Translation2d(args.fieldSizeMeters.width - robotRadius,
            args.fieldSizeMeters.height - robotRadius);
        for (Waypoint w in args.path.waypoints) {
          if (w.anchor.x < minPos.x ||
              w.anchor.y < minPos.y ||
              w.anchor.x > maxPos.x ||
              w.anchor.y > maxPos.y) {
            preventFieldExit = false;
            break;
          }
        }

        // Generate an initial population
        List<_Individual> population = List.generate(populationSize, (index) {
          List<Waypoint> mutatedPoints = [];
          final p = args.path.duplicate(args.path.name);
          // mutate all waypoints
          for (int i = 0; i < p.waypoints.length; i++) {
            mutatedPoints.add(_Individual.mutate(p.waypoints[i]));
          }
          p.waypoints = mutatedPoints;
          _Individual individual =
              _Individual(p, args.config, minPos, maxPos, preventFieldExit);
          return individual;
        });

        // Repeat until max iterations:
        //    a. Select parents from population
        //    b. Crossover and generate new population
        //    c. Perform mutation on population
        //    d. Calculate fitness of new population
        int generation = 1;
        OptimizationResult? bestFit;
        while (generation <= generations) {
          population.sort((a, b) => a.fitness.compareTo(b.fitness));

          // Fittest 10% of population moves to next generation
          List<_Individual> nextGen = List.generate(
              (populationSize * 0.1).floor(), (index) => population[index]);

          // Fittest 50% of population will produce offspring
          for (int i = 0; i < (populationSize * 0.9).floor(); i++) {
            final parent1 =
                population[rand.nextInt((populationSize * 0.5).floor())];
            final parent2 =
                population[rand.nextInt((populationSize * 0.5).floor())];
            nextGen.add(parent1.crossover(parent2));
          }

          if (bestFit == null || population.first.fitness < bestFit.runtime) {
            bestFit = OptimizationResult(
                population.first.path, population.first.fitness, generation);
          } else {
            bestFit = bestFit.withGeneration(generation);
          }
          controller.sendResult(bestFit);

          population = nextGen;
          generation++;
        }

        // Return final value
        if (bestFit != null) {
          return bestFit;
        } else {
          // Something broke real bad, return original path
          return OptimizationResult(args.path, -1.0, generations);
        }
      },
    );
  }
}

class OptimizationResult {
  final PathPlannerPath path;
  final num runtime;
  final int generation;

  const OptimizationResult(this.path, this.runtime, this.generation);

  OptimizationResult withGeneration(int gen) {
    return OptimizationResult(path, runtime, gen);
  }
}

class _Individual {
  final PathPlannerPath path;
  final RobotConfig config;
  late final num fitness;
  final Translation2d minPos;
  final Translation2d maxPos;
  final bool preventFieldExit;

  _Individual(
      this.path, this.config, this.minPos, this.maxPos, this.preventFieldExit) {
    path.generatePathPoints();

    bool shouldGenerate = true;

    if (preventFieldExit) {
      // Check all path points for a potential field exit
      for (PathPoint p in path.pathPoints) {
        if (p.position.x < minPos.x ||
            p.position.y < minPos.y ||
            p.position.x > maxPos.x ||
            p.position.y > maxPos.y) {
          fitness = double.infinity;
          shouldGenerate = false;
          break;
        }
      }
    }

    if (shouldGenerate) {
      fitness = PathPlannerTrajectory(path: path, robotConfig: config)
          .getTotalTimeSeconds();
    }
  }

  /// Produce a new offspring from 2 parents
  _Individual crossover(_Individual parent2) {
    List<Waypoint> childWaypoints = [];
    for (int i = 0; i < path.waypoints.length; i++) {
      double prob = Random().nextDouble();

      if (prob < 0.3) {
        // If prob is less than 0.3, insert waypoint (gene) from parent 1
        childWaypoints.add(path.waypoints[i]);
      } else if (prob < 0.6) {
        // If prob is between 0.3 and 0.6, insert gene from parent 2
        childWaypoints.add(parent2.path.waypoints[i]);
      } else {
        // Otherwise, insert mutated gene
        childWaypoints.add(mutate(path.waypoints[i]));
      }
    }

    PathPlannerPath offspringPath = path.duplicate(path.name);
    offspringPath.waypoints = childWaypoints;
    return _Individual(offspringPath, config, minPos, maxPos, preventFieldExit);
  }

  void calculateFitness(RobotConfig config) {
    path.generatePathPoints();

    var traj = PathPlannerTrajectory(path: path, robotConfig: config);
    fitness = traj.getTotalTimeSeconds();
  }

  static Waypoint mutate(Waypoint original) {
    Waypoint mutated = original.clone();

    var rand = Random();

    // Mutate by changing the heading randomly between +/- 10 deg
    double theta = (rand.nextDouble() - 0.5) * 10.0;
    mutated.setHeading(mutated.heading + Rotation2d.fromDegrees(theta));

    if (mutated.prevControl != null) {
      // Mutate by changing prev control length randomly between +/- 0.2 m
      double x = (rand.nextDouble() - 0.5) * 0.2;
      double prevLength = mutated.prevControlLength! + x;
      mutated.setPrevControlLength(prevLength);
    }

    if (mutated.nextControl != null) {
      // Mutate by changing next control length randomly between +/- 0.2 m
      double x = (rand.nextDouble() - 0.5) * 0.2;
      double nextLength = mutated.nextControlLength! + x;
      mutated.setNextControlLength(nextLength);
    }

    return mutated;
  }
}

class _OptimizerArgs {
  final PathPlannerPath path;
  final RobotConfig config;
  final Size fieldSizeMeters;
  final Size robotSizeMeters;

  const _OptimizerArgs(
      this.path, this.config, this.fieldSizeMeters, this.robotSizeMeters);
}
