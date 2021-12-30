import 'dart:math';

import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/generator/geometry_util.dart';

class Trajectory {
  final List<State> states;

  Trajectory(this.states);

  static Future<Trajectory> generateTrajectory(
      RobotPath path, bool reversed) async {
    List<State> joined =
        joinSplines(path.waypoints, path.maxVelocity ?? 8.0, 0.004);
    calculateMaxVel(
        joined, path.maxVelocity ?? 8.0, path.maxAcceleration ?? 5.0);
    calculateVelocity(joined, path.waypoints, path.maxAcceleration ?? 5.0);
    recalculateValues(joined, reversed);

    return Trajectory(joined);
  }

  State sample(num time) {
    if (time <= states[0].timeSeconds) return states[0];
    if (time >= states[states.length - 1].timeSeconds)
      return states[states.length - 1];

    int low = 1;
    int high = states.length - 1;

    while (low != high) {
      int mid = (low + high) ~/ 2;
      if (states[mid].timeSeconds < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    State sample = states[low];
    State prevSample = states[low - 1];

    if ((sample.timeSeconds - prevSample.timeSeconds).abs() < 1E-3)
      return sample;

    return prevSample.interpolate(
        sample,
        (time - prevSample.timeSeconds) /
            (sample.timeSeconds - prevSample.timeSeconds));
  }

  static void calculateMaxVel(List<State> states, num maxVel, num maxAccel) {
    for (int i = 0; i < states.length; i++) {
      num radius;
      if (i == states.length - 1) {
        radius = calculateRadius(states[i - 2], states[i - 1], states[i]);
      } else if (i == 0) {
        radius = calculateRadius(states[i], states[i + 1], states[i + 2]);
      } else {
        radius = calculateRadius(states[i - 1], states[i], states[i + 1]);
      }

      if (!radius.isFinite || radius.isNaN) {
        states[i].velocityMetersPerSecond =
            min(maxVel, states[i].velocityMetersPerSecond);
      } else {
        states[i].curveRadius = radius;
        num maxVCurve = sqrt(maxAccel * radius);
        states[i].velocityMetersPerSecond =
            min(maxVCurve, states[i].velocityMetersPerSecond);
      }
    }
  }

  static void calculateVelocity(
      List<State> states, List<Waypoint> pathPoints, num maxAccel) {
    if (pathPoints[0].velOverride == null) {
      states[0].velocityMetersPerSecond = 0;
    }

    for (int i = 1; i < states.length; i++) {
      num v0 = states[i - 1].velocityMetersPerSecond;
      num deltaPos = states[i].deltaPos;

      if (deltaPos > 0) {
        num vMax = sqrt(((v0 * v0) + (2 * maxAccel * deltaPos)).abs());
        states[i].velocityMetersPerSecond =
            min(vMax, states[i].velocityMetersPerSecond);
      } else {
        states[i].velocityMetersPerSecond =
            states[i - 1].velocityMetersPerSecond;
      }
    }

    if (pathPoints[pathPoints.length - 1].velOverride == null) {
      states[states.length - 1].velocityMetersPerSecond = 0;
    }
    for (int i = states.length - 2; i > 1; i--) {
      num v0 = states[i + 1].velocityMetersPerSecond;
      num deltaPos = states[i + 1].deltaPos;

      double vMax = sqrt(((v0 * v0) + (2 * maxAccel * deltaPos)).abs());
      states[i].velocityMetersPerSecond =
          min(vMax, states[i].velocityMetersPerSecond);
    }

    num time = 0;
    for (int i = 1; i < states.length; i++) {
      num v = states[i].velocityMetersPerSecond;
      num deltaPos = states[i].deltaPos;
      num v0 = states[i - 1].velocityMetersPerSecond;

      time += (2 * deltaPos) / (v + v0);
      states[i].timeSeconds = time;

      num dv = v - v0;
      num dt = time - states[i - 1].timeSeconds;

      if (dt == 0) {
        states[i].accelerationMetersPerSecondSq = 0;
      } else {
        states[i].accelerationMetersPerSecondSq = dv / dt;
      }
    }
  }

  static void recalculateValues(List<State> states, bool reversed) {
    for (int i = 0; i < states.length; i++) {
      State now = states[i];

      if (reversed) {
        now.positionMeters *= -1;
        now.velocityMetersPerSecond *= -1;
        now.accelerationMetersPerSecondSq *= -1;

        num h = now.headingRadians + pi;
        if (h > pi) {
          h -= 2 * pi;
        } else if (h < -pi) {
          h += 2 * pi;
        }
        now.headingRadians = h;
      }

      if (i != 0) {
        State last = states[i - 1];

        num dt = now.timeSeconds - last.timeSeconds;
        now.velocityMetersPerSecond =
            (now.positionMeters - last.positionMeters) / dt;
        now.accelerationMetersPerSecondSq =
            (now.velocityMetersPerSecond - last.velocityMetersPerSecond) / dt;

        now.angularVelocity = (now.headingRadians - last.headingRadians) / dt;
        now.angularAcceleration =
            (now.angularVelocity - last.angularVelocity) / dt;
      }

      now.curvatureRadPerMeter = 1 / now.curveRadius;
    }
  }

  static List<State> joinSplines(
      List<Waypoint> pathPoints, num maxVel, double step) {
    List<State> states = [];
    int numSplines = pathPoints.length - 1;

    for (int i = 0; i < numSplines; i++) {
      Waypoint startPoint = pathPoints[i];
      Waypoint endPoint = pathPoints[i + 1];

      double endStep = (i == numSplines - 1) ? 1.0 : 1.0 - step;
      for (double t = 0; t <= endStep; t += step) {
        Point p = GeometryUtil.cubicLerp(
            startPoint.anchorPoint,
            startPoint.nextControl!,
            endPoint.prevControl!,
            endPoint.anchorPoint,
            t);

        State state = State();
        state.translationMeters = p;

        double deltaRot = endPoint.holonomicAngle - startPoint.holonomicAngle;
        if (deltaRot > 180) {
          deltaRot -= 360;
        } else if (deltaRot < -180) {
          deltaRot += 360;
        }

        double holonomicRot = startPoint.holonomicAngle + (deltaRot * t);
        state.holonomicRotation = holonomicRot;

        if (i > 0 || t > 0) {
          State s1 = states[states.length - 1];
          State s2 = state;
          double hypot = s1.translationMeters.distanceTo(s2.translationMeters);
          state.positionMeters = s1.positionMeters + hypot;
          state.deltaPos = hypot;

          double heading = atan2(
                  s1.translationMeters.y - s2.translationMeters.y,
                  s1.translationMeters.x - s2.translationMeters.x) +
              pi;
          if (heading > pi) {
            heading -= 2 * pi;
          } else if (heading < -pi) {
            heading += 2 * pi;
          }
          state.headingRadians = heading;

          if (i == 0 && t == step) {
            states[states.length - 1].headingRadians = heading;
          }
        }

        if (t == 0.0) {
          state.velocityMetersPerSecond = startPoint.velOverride ?? maxVel;
        } else if (t == 1.0) {
          state.velocityMetersPerSecond = endPoint.velOverride ?? maxVel;
        } else {
          state.velocityMetersPerSecond = maxVel;
        }

        states.add(state);
      }
    }
    return states;
  }

  static num calculateRadius(State s0, State s1, State s2) {
    num ab = s0.translationMeters.distanceTo(s1.translationMeters);
    num bc = s1.translationMeters.distanceTo(s2.translationMeters);
    num ac = s0.translationMeters.distanceTo(s2.translationMeters);

    num p = (ab + bc + ac) / 2;
    num area = sqrt((p * (p - ab) * (p - bc) * (p - ac)).abs());
    return (ab * bc * ac) / (4 * area);
  }
}

class State {
  num timeSeconds = 0.0;
  num velocityMetersPerSecond = 0.0;
  num accelerationMetersPerSecondSq = 0.0;
  Point translationMeters = Point(0, 0);
  num headingRadians = 0.0;
  num curvatureRadPerMeter = 0.0;
  num positionMeters = 0.0;
  num angularVelocity = 0.0;
  num angularAcceleration = 0.0;
  num holonomicRotation = 0.0;

  num curveRadius = 0.0;
  num deltaPos = 0.0;

  State interpolate(State endVal, num t) {
    State lerpedState = State();

    lerpedState.timeSeconds =
        GeometryUtil.numLerp(this.timeSeconds, endVal.timeSeconds, t);
    num deltaT = lerpedState.timeSeconds - this.timeSeconds;

    if (deltaT < 0) {
      return endVal.interpolate(this, 1 - t);
    }

    lerpedState.velocityMetersPerSecond =
        velocityMetersPerSecond + (accelerationMetersPerSecondSq * deltaT);
    lerpedState.positionMeters = (velocityMetersPerSecond * deltaT) +
        (0.5 * accelerationMetersPerSecondSq * deltaT * deltaT);
    lerpedState.accelerationMetersPerSecondSq = GeometryUtil.numLerp(
        this.accelerationMetersPerSecondSq,
        endVal.accelerationMetersPerSecondSq,
        t);
    lerpedState.translationMeters = GeometryUtil.pointLerp(
        this.translationMeters, endVal.translationMeters, t);
    lerpedState.headingRadians =
        GeometryUtil.numLerp(this.headingRadians, endVal.headingRadians, t);
    lerpedState.curvatureRadPerMeter = GeometryUtil.numLerp(
        this.curvatureRadPerMeter, endVal.curvatureRadPerMeter, t);
    lerpedState.angularVelocity =
        GeometryUtil.numLerp(this.angularVelocity, endVal.angularVelocity, t);
    lerpedState.angularAcceleration = GeometryUtil.numLerp(
        this.angularAcceleration, endVal.angularAcceleration, t);
    lerpedState.holonomicRotation = GeometryUtil.numLerp(
        this.holonomicRotation, endVal.holonomicRotation, t);
    lerpedState.curveRadius =
        GeometryUtil.numLerp(this.curveRadius, endVal.curveRadius, t);
    lerpedState.deltaPos =
        GeometryUtil.numLerp(this.deltaPos, endVal.deltaPos, t);

    return lerpedState;
  }
}
