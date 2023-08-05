import 'dart:math';

import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/simulator/chassis_speeds.dart';
import 'package:pathplanner/services/simulator/chassis_speeds_limiter.dart';
import 'package:pathplanner/services/simulator/rotation_p_controller.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/pose2d.dart';

const num simulationPeriod = 0.02;
const num minLookahead = 0.5;

class SimulatableAuto {
  final List<PathPlannerPath> paths;
  final Pose2d? startingPose;

  const SimulatableAuto({
    required this.paths,
    this.startingPose,
  });
}

Future<SimulatedPath> simulateAutoHolonomic(SimulatableAuto auto) async {
  SimulatedPath sim = SimulatedPath();

  if (auto.paths.isNotEmpty) {
    SimulatedPath path =
        await _simulatePath(auto.paths.first, auto.startingPose, null, true);

    sim.runtime += path.runtime;
    sim.pathStates.addAll(path.pathStates);

    for (int i = 1; i < auto.paths.length; i++) {
      path = await _simulatePath(
          auto.paths[i], sim.pathStates.last, path.endSpeeds, true);

      sim.runtime += path.runtime;
      sim.pathStates.addAll(path.pathStates);
    }

    sim.endSpeeds = path.endSpeeds;
  }

  return sim;
}

Future<SimulatedPath> simulateAutoDifferential(SimulatableAuto auto) async {
  SimulatedPath sim = SimulatedPath();

  if (auto.paths.isNotEmpty) {
    SimulatedPath path =
        await _simulatePath(auto.paths.first, auto.startingPose, null, false);

    sim.runtime += path.runtime;
    sim.pathStates.addAll(path.pathStates);

    for (int i = 1; i < auto.paths.length; i++) {
      path = await _simulatePath(
          auto.paths[i], sim.pathStates.last, path.endSpeeds, false);

      sim.runtime += path.runtime;
      sim.pathStates.addAll(path.pathStates);
    }

    sim.endSpeeds = path.endSpeeds;
  }

  return sim;
}

Future<SimulatedPath> simulatePathHolonomic(PathPlannerPath path) {
  return _simulatePath(path, null, null, true);
}

Future<SimulatedPath> simulatePathDifferential(PathPlannerPath path) {
  return _simulatePath(path, null, null, false);
}

Future<SimulatedPath> _simulatePath(PathPlannerPath path, Pose2d? startingPose,
    ChassisSpeeds? startingSpeeds, bool holonomic) async {
  SimulatedPath sim = SimulatedPath();

  if (path.pathPoints.length < 2) {
    return sim;
  }

  Pose2d currentPose =
      startingPose?.clone() ?? Pose2d(position: path.pathPoints.first.position);
  sim.pathStates.add(Pose2d(
    position: currentPose.position,
    rotation: currentPose.rotation,
  ));
  ChassisSpeeds currentSpeeds = startingSpeeds ?? ChassisSpeeds();
  ChassisSpeedsLimiter limiter = ChassisSpeedsLimiter(
    translationLimit: path.globalConstraints.maxAcceleration,
    rotationLimit: path.globalConstraints.maxAngularAcceleration,
    initialValue: currentSpeeds,
  );
  RotationPController rotationController = const RotationPController(kP: 4.0);
  Point? lastLookahead;
  num lastDistToEnd = double.infinity;
  PathPoint nextRotationTarget = _findNextRotationTarget(path, 0);
  bool lockDecel = false;
  num lastHeadingRadians = 0;

  while (true) {
    int closestPointIdx =
        _getClosestPointIndex(currentPose.position, path.pathPoints);
    PathConstraints constraints = path.pathPoints[closestPointIdx].constraints;
    limiter.setRateLimits(
        constraints.maxAcceleration, constraints.maxAngularAcceleration);

    num currentRobotVel =
        sqrt(pow(currentSpeeds.vx, 2) + pow(currentSpeeds.vy, 2));

    num lookaheadDistance = _getLookaheadDistance(currentRobotVel, constraints);
    lastLookahead =
        _getLookaheadPoint(path, currentPose.position, lookaheadDistance);

    if (lastLookahead == null) {
      num extraLookahead = 0.2;
      while (lastLookahead == null) {
        if (extraLookahead > 1.0) {
          lastLookahead = path.pathPoints[0].position;
          break;
        }
        lastLookahead = _getLookaheadPoint(
            path, currentPose.position, lookaheadDistance + extraLookahead);
        extraLookahead += 0.2;
      }
    }

    if (path.pathPoints[closestPointIdx].distanceAlongPath >
        nextRotationTarget.distanceAlongPath) {
      nextRotationTarget = _findNextRotationTarget(path, closestPointIdx);
    }

    num distanceToEnd =
        currentPose.position.distanceTo(path.pathPoints.last.position);

    // Lock in the heading at the end of the path so it doesn't get all wonky
    // as the heading changes wildly
    if (distanceToEnd > 0.1) {
      lastHeadingRadians = atan2(lastLookahead.y - currentPose.position.y,
          lastLookahead.x - currentPose.position.x);
    }

    num maxAngVel = constraints.maxAngularVelocity;
    num rotationVel = (rotationController.calculate(
            currentPose.rotation,
            holonomic
                ? nextRotationTarget.holonomicRotation!
                : GeometryUtil.toDegrees(lastHeadingRadians)))
        .clamp(-maxAngVel, maxAngVel);

    if (path.goalEndState.velocity == 0 && !lockDecel) {
      num neededDecel = pow(currentRobotVel, 2) / (2 * distanceToEnd);
      if (neededDecel >= constraints.maxAcceleration) {
        lockDecel = true;
      }
    }

    if (lockDecel) {
      num neededDecel = pow(currentRobotVel, 2) / (2 * distanceToEnd);

      num nextVel = max(path.goalEndState.velocity,
          currentRobotVel - (neededDecel * simulationPeriod));
      if (neededDecel < constraints.maxAcceleration * 0.9) {
        nextVel = sqrt(pow(currentSpeeds.vx, 2) + pow(currentSpeeds.vy, 2));
      }

      if (holonomic) {
        num velX = nextVel * cos(lastHeadingRadians);
        num velY = nextVel * sin(lastHeadingRadians);

        currentSpeeds = ChassisSpeeds(
          vx: velX,
          vy: velY,
          omega: rotationVel,
        );
      } else {
        currentSpeeds = ChassisSpeeds(vx: nextVel, omega: rotationVel);
      }

      limiter.reset(currentSpeeds);
    } else {
      num maxV =
          min(constraints.maxVelocity, path.pathPoints[closestPointIdx].maxV);

      num stoppingDist =
          pow(currentRobotVel, 2) / (2 * constraints.maxAcceleration);

      for (int i = closestPointIdx; i < path.pathPoints.length; i++) {
        if (currentPose.position.distanceTo(path.pathPoints[i].position) >
            stoppingDist) {
          break;
        }

        PathPoint p = path.pathPoints[i];
        if (p.maxV < currentRobotVel) {
          num dist = currentPose.position.distanceTo(p.position);
          num neededDecel =
              (pow(currentRobotVel, 2) - pow(p.maxV, 2)) / (2 * dist);
          if (neededDecel >= constraints.maxAcceleration) {
            maxV = p.maxV;
            break;
          }
        }
      }

      if (holonomic) {
        currentSpeeds = limiter.calculate(
          ChassisSpeeds(
            vx: maxV * cos(lastHeadingRadians),
            vy: maxV * sin(lastHeadingRadians),
            omega: rotationVel,
          ),
          simulationPeriod,
        );
      } else {
        currentSpeeds = limiter.calculate(
          ChassisSpeeds(
            vx: maxV,
            omega: rotationVel,
          ),
          simulationPeriod,
        );
      }
    }

    num nextX;
    num nextY;
    num nextRot =
        currentPose.rotation + (currentSpeeds.omega * simulationPeriod);
    nextRot %= 360;
    if (nextRot > 180) {
      nextRot -= 360;
    }

    if (holonomic) {
      nextX = currentPose.position.x + (currentSpeeds.vx * simulationPeriod);
      nextY = currentPose.position.y + (currentSpeeds.vy * simulationPeriod);
    } else {
      nextX = currentPose.position.x +
          (currentSpeeds.vx *
              cos(GeometryUtil.toRadians(nextRot)) *
              simulationPeriod);
      nextY = currentPose.position.y +
          (currentSpeeds.vx *
              sin(GeometryUtil.toRadians(nextRot)) *
              simulationPeriod);
    }

    currentPose.position = Point(nextX, nextY);
    currentPose.rotation = nextRot;

    num actualRotation = currentPose.rotation;
    if (path.reversed && !holonomic) {
      actualRotation += 180;
      actualRotation %= 360;
      if (actualRotation > 180) {
        actualRotation -= 360;
      }
    }

    sim.pathStates
        .add(Pose2d(position: currentPose.position, rotation: actualRotation));
    sim.runtime += simulationPeriod;

    // Check if we're finished following
    Point endPos = path.pathPoints.last.position;
    if (_pointEquals(lastLookahead, endPos)) {
      num distanceToEnd = currentPose.position.distanceTo(endPos);
      if (path.goalEndState.velocity != 0 && distanceToEnd <= 0.1) {
        break;
      }

      if (distanceToEnd >= lastDistToEnd) {
        if (holonomic && path.goalEndState.velocity == 0) {
          num currentVel =
              sqrt(pow(currentSpeeds.vx, 2) + pow(currentSpeeds.vy, 2));
          if (currentVel <= 0.1) {
            break;
          }
        } else {
          break;
        }
      }

      lastDistToEnd = distanceToEnd;
    }
  }

  sim.endSpeeds = currentSpeeds;
  return sim;
}

bool _pointEquals(Point a, Point b) {
  return (a.x - b.x).abs() <= 0.001 && (a.y - b.y).abs() <= 0.001;
}

num _getLookaheadDistance(num currentVel, PathConstraints constraints) {
  num lookaheadFactor = 1.0 - (0.1 * constraints.maxAcceleration);
  return max(lookaheadFactor * currentVel, minLookahead);
}

Point? _getLookaheadPoint(PathPlannerPath path, Point robotPos, num r) {
  Point? lookahead;

  for (int i = 0; i < path.pathPoints.length - 1; i++) {
    Point segmentStart = path.pathPoints[i].position;
    Point segmentEnd = path.pathPoints[i + 1].position;

    Point p1 = segmentStart - robotPos;
    Point p2 = segmentEnd - robotPos;

    num dx = p2.x - p1.x;
    num dy = p2.y - p1.y;

    num d = sqrt(pow(dx, 2) + pow(dy, 2));
    num D = p1.x * p2.y - p2.x * p1.y;

    num discriminant = pow(r, 2) * pow(d, 2) - pow(D, 2);
    if (discriminant < 0 || p1 == p2) {
      continue;
    }

    num signDy = dy.sign;
    if (signDy.abs() == 0.0) {
      signDy = 1.0;
    }

    num x1 = (D * dy + signDy * dx * sqrt(discriminant)) / pow(d, 2);
    num x2 = (D * dy - signDy * dx * sqrt(discriminant)) / pow(d, 2);

    num v = dy.abs() * sqrt(discriminant);
    num y1 = (-D * dx + v) / pow(d, 2);
    num y2 = (-D * dx - v) / pow(d, 2);

    bool validIntersection1 = min(p1.x, p2.x) < x1 && x1 < max(p1.x, p2.x) ||
        min(p1.y, p2.y) < y1 && y1 < max(p1.y, p2.y);
    bool validIntersection2 = min(p1.x, p2.x) < x2 && x2 < max(p1.x, p2.x) ||
        min(p1.y, p2.y) < y2 && y2 < max(p1.y, p2.y);

    if (validIntersection1 && !(validIntersection2 && signDy < 0)) {
      lookahead = Point(x1, y1) + robotPos;
    } else if (validIntersection2) {
      lookahead = Point(x2, y2) + robotPos;
    }
  }

  if (path.pathPoints.isNotEmpty) {
    Point lastPoint = path.pathPoints.last.position;

    if ((lastPoint - robotPos).magnitude <= r) {
      return lastPoint;
    }
  }

  return lookahead;
}

PathPoint _findNextRotationTarget(PathPlannerPath path, int startIndex) {
  for (int i = startIndex; i < path.pathPoints.length; i++) {
    if (path.pathPoints[i].holonomicRotation != null) {
      return path.pathPoints[i];
    }
  }
  return path.pathPoints.last;
}

int _getClosestPointIndex(Point p, List<PathPoint> points) {
  if (points.isEmpty) {
    return -1;
  }

  int closestIdx = 0;
  num closestDist = _positionDelta(p, points[closestIdx].position);

  for (int i = 1; i < points.length; i++) {
    num d = _positionDelta(p, points[i].position);

    if (d < closestDist) {
      closestIdx = i;
      closestDist = d;
    }
  }

  return closestIdx;
}

num _positionDelta(Point a, Point b) {
  Point delta = a - b;
  return delta.x.abs() + delta.y.abs();
}

class SimulatedPath {
  num runtime;
  List<Pose2d> pathStates;
  ChassisSpeeds endSpeeds;

  SimulatedPath()
      : runtime = 0,
        pathStates = [],
        endSpeeds = ChassisSpeeds();

  Pose2d? getState(num time) {
    if (pathStates.isEmpty) {
      return null;
    }

    int floorIndex = (time / simulationPeriod).floor();
    int ceilIndex = (time / simulationPeriod).ceil();
    if (floorIndex > pathStates.length - 1 ||
        ceilIndex > pathStates.length - 1) {
      return pathStates.last;
    } else if (floorIndex == ceilIndex) {
      return pathStates[floorIndex];
    } else {
      num d = (time / simulationPeriod);
      num t = (d - floorIndex) / (ceilIndex - floorIndex);

      Point lerpedPos = GeometryUtil.pointLerp(
          pathStates[floorIndex].position, pathStates[ceilIndex].position, t);
      num lerpedRot = GeometryUtil.numLerp(
          pathStates[floorIndex].rotation, pathStates[ceilIndex].rotation, t);

      return Pose2d(position: lerpedPos, rotation: lerpedRot);
    }
  }
}
