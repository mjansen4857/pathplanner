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

Future<SimulatedPath> simulatePath(PathPlannerPath path,
    [Pose2d? startingPose, ChassisSpeeds? startingSpeeds]) async {
  SimulatedPath sim = SimulatedPath();

  if (path.pathPoints.length < 2) {
    return sim;
  }

  Pose2d currentPose =
      startingPose ?? Pose2d(position: path.pathPoints.first.position);
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

  bool finished = false;

  while (!finished) {
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

    num rotationVel = 0;
    if (path.pathPoints[closestPointIdx].distanceAlongPath >
        nextRotationTarget.distanceAlongPath) {
      nextRotationTarget = _findNextRotationTarget(path, closestPointIdx);
    }

    num maxAngVel = constraints.maxAngularVelocity;

    rotationVel = (rotationController.calculate(
            currentPose.rotation, nextRotationTarget.holonomicRotation!))
        .clamp(-maxAngVel, maxAngVel);

    num headingRadians = atan2(lastLookahead.y - currentPose.position.y,
        lastLookahead.x - currentPose.position.x);

    num distanceToEnd =
        currentPose.position.distanceTo(path.pathPoints.last.position);
    num neededDecel = pow(currentRobotVel - path.goalEndState.velocity, 2) /
        (2 * distanceToEnd);

    if (lockDecel ||
        (currentRobotVel > path.goalEndState.velocity &&
            neededDecel >= constraints.maxAcceleration)) {
      lockDecel = true;

      num nextVel = max(path.goalEndState.velocity,
          currentRobotVel - (neededDecel * simulationPeriod));
      if (neededDecel < constraints.maxAcceleration * 0.9) {
        nextVel = sqrt(pow(currentSpeeds.vx, 2) + pow(currentSpeeds.vy, 2));
      }
      num velX = nextVel * cos(headingRadians);
      num velY = nextVel * sin(headingRadians);

      currentSpeeds = ChassisSpeeds(
        vx: velX,
        vy: velY,
        omega: rotationVel,
      );
      limiter.reset(currentSpeeds);
    } else {
      num maxV = constraints.maxVelocity;

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
          if (neededDecel >= constraints.maxAcceleration ||
              i == closestPointIdx) {
            maxV = p.maxV;
            break;
          }
        }
      }

      currentSpeeds = limiter.calculate(
        ChassisSpeeds(
          vx: maxV * cos(headingRadians),
          vy: maxV * sin(headingRadians),
          omega: rotationVel,
        ),
        simulationPeriod,
      );
    }

    num nextX = currentPose.position.x + (currentSpeeds.vx * simulationPeriod);
    num nextY = currentPose.position.y + (currentSpeeds.vy * simulationPeriod);
    num nextRot =
        currentPose.rotation + (currentSpeeds.omega * simulationPeriod);
    nextRot %= 360;
    if (nextRot > 180) {
      nextRot -= 360;
    }

    currentPose.position = Point(nextX, nextY);
    currentPose.rotation = nextRot;

    sim.pathStates.add(
        Pose2d(position: currentPose.position, rotation: currentPose.rotation));
    sim.runtime += simulationPeriod;

    // Check if we're finished following
    Point endPos = path.pathPoints.last.position;
    if (_pointEquals(lastLookahead, endPos)) {
      num distanceToEnd = currentPose.position.distanceTo(endPos);
      if (distanceToEnd >= lastDistToEnd || path.goalEndState.velocity == 0) {
        if (path.goalEndState.velocity == 0) {
          num currentVel =
              sqrt(pow(currentSpeeds.vx, 2) + pow(currentSpeeds.vy, 2));
          if (currentVel.abs() <= 0.1) {
            finished = true;
          }
        } else {
          finished = true;
        }
      }
      lastDistToEnd = distanceToEnd;
    }
  }

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

  SimulatedPath()
      : runtime = 0,
        pathStates = [];

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
