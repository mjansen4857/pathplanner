import 'dart:math';

import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/simulator/chassis_speeds.dart';
import 'package:pathplanner/services/simulator/chassis_speeds_limiter.dart';
import 'package:pathplanner/services/simulator/rotation_p_controller.dart';
import 'package:pathplanner/util/pose2d.dart';

class PathSimulator {
  static const num simulationPeriod = 0.02;
  static const num minLookahead = 0.5;

  static Future<SimulatedPath> simulate(PathPlannerPath path) async {
    SimulatedPath sim = SimulatedPath();

    ChassisSpeedsLimiter limiter = ChassisSpeedsLimiter(
      translationLimit: path.globalConstraints.maxAcceleration,
      rotationLimit: path.globalConstraints.maxAngularAcceleration,
    );
    RotationPController rotationController = const RotationPController(kP: 4.0);
    Point lastLookahead = const Point(0, 0);
    num lastDistToEnd = double.infinity;
    ChassisSpeeds lastCommanded;
    PathPoint nextRotationTarget = _findNextRotationTarget(path, 0);
    bool lockDecel = false;

    // TODO

    return sim;
  }

  static PathPoint _findNextRotationTarget(
      PathPlannerPath path, int startIndex) {
    // TODO
    return path.pathPoints.last;
  }
}

class SimulatedPath {
  num runtime;
  List<Pose2d> pathStates;

  SimulatedPath()
      : runtime = 0,
        pathStates = [];

  Pose2d? getState(num time) {
    if (pathStates.isEmpty) {
      return null;
    }

    int index = (time / PathSimulator.simulationPeriod).floor();
    if (index > pathStates.length - 1) {
      return pathStates.last;
    } else {
      return pathStates[index];
    }
  }
}
