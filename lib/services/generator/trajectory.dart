import 'dart:convert';
import 'dart:math';

import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/generator/geometry_util.dart';
import 'package:pathplanner/services/generator/math_util.dart';

class Trajectory {
  static const double resolution = 0.004;
  late final List<TrajectoryState> states;

  Trajectory(this.states);

  Trajectory.joinTrajectories(List<Trajectory> trajectories) {
    List<TrajectoryState> joinedStates = [];

    for (int i = 0; i < trajectories.length; i++) {
      if (i != 0) {
        num lastEndTime = joinedStates.last.timeSeconds;

        for (TrajectoryState s in trajectories[i].states) {
          s.timeSeconds += lastEndTime;
        }
      }

      joinedStates.addAll(trajectories[i].states);
    }

    states = joinedStates;
  }

  String getWPILibJSON() {
    return jsonEncode(states);
  }

  String getCSV() {
    String csv = TrajectoryState.getCSVHeader();

    for (TrajectoryState s in states) {
      csv += '\n ${s.toCSV()}';
    }

    return csv;
  }

  static Future<Trajectory> generateFullTrajectory(RobotPath path) async {
    List<List<Waypoint>> splitPaths = [];
    List<Waypoint> currentPath = [];

    for (int i = 0; i < path.waypoints.length; i++) {
      Waypoint w = path.waypoints[i];

      currentPath.add(w);

      if (w.isReversal || w.isStopPoint || i == path.waypoints.length - 1) {
        splitPaths.add(currentPath);
        currentPath = [];
        currentPath.add(w);
      }
    }

    List<Trajectory> trajectories = [];
    bool shouldReverse = path.isReversed ?? false;
    for (int i = 0; i < splitPaths.length; i++) {
      List<Waypoint> splitPath = splitPaths[i];
      trajectories.add(await generateSingleTrajectory(
          splitPath, path.maxVelocity, path.maxAcceleration, shouldReverse));

      if (splitPath[splitPath.length - 1].isReversal) {
        shouldReverse = !shouldReverse;
      }
    }

    Trajectory trajectory = Trajectory.joinTrajectories(trajectories);

    calculateAllMarkerTimes(trajectory, path.markers);

    return trajectory;
  }

  static Future<Trajectory> generateSingleTrajectory(List<Waypoint> pathPoints,
      num? maxVel, num? maxAccel, bool reversed) async {
    List<TrajectoryState> joined =
        joinSplines(pathPoints, maxVel ?? 4.0, Trajectory.resolution);
    calculateMaxVel(joined, maxVel ?? 4.0, maxAccel ?? 3.0, reversed);
    calculateVelocity(joined, pathPoints, maxAccel ?? 3.0);
    recalculateValues(joined, reversed);

    return Trajectory(joined);
  }

  static void calculateMarkerTime(
      Trajectory trajectory, EventMarker marker) async {
    int statesPerWaypoint = 1 ~/ Trajectory.resolution;
    int startIndex =
        (statesPerWaypoint * marker.position).floor() - marker.position.floor();
    double t = (statesPerWaypoint * marker.position) % 1;

    if (startIndex == trajectory.states.length - 1) {
      startIndex--;
      t = 1;
    }
    num start = trajectory.states[startIndex].timeSeconds;
    num end = trajectory.states[startIndex + 1].timeSeconds;

    marker.timeSeconds = GeometryUtil.numLerp(start, end, t).toDouble();
  }

  static void calculateAllMarkerTimes(
      Trajectory trajectory, List<EventMarker> markers) async {
    for (EventMarker marker in markers) {
      calculateMarkerTime(trajectory, marker);
    }
  }

  TrajectoryState sample(num time) {
    if (time <= states[0].timeSeconds) return states[0];
    if (time >= states[states.length - 1].timeSeconds) {
      return states[states.length - 1];
    }

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

    TrajectoryState sample = states[low];
    TrajectoryState prevSample = states[low - 1];

    if ((sample.timeSeconds - prevSample.timeSeconds).abs() < 1E-3) {
      return sample;
    }

    return prevSample.interpolate(
        sample,
        (time - prevSample.timeSeconds) /
            (sample.timeSeconds - prevSample.timeSeconds));
  }

  num getRuntime() {
    return states.last.timeSeconds;
  }

  num getLength() {
    num length = 0;

    for (TrajectoryState state in states) {
      length += state.deltaPos.abs();
    }
    return length;
  }

  static void calculateMaxVel(
      List<TrajectoryState> states, num maxVel, num maxAccel, bool reversed) {
    for (int i = 0; i < states.length; i++) {
      num radius;
      if (i == states.length - 1) {
        radius = calculateRadius(states[i - 2], states[i - 1], states[i]);
      } else if (i == 0) {
        radius = calculateRadius(states[i], states[i + 1], states[i + 2]);
      } else {
        radius = calculateRadius(states[i - 1], states[i], states[i + 1]);
      }

      if (reversed) {
        radius *= -1;
      }

      if (!radius.isFinite || radius.isNaN) {
        states[i].velocityMetersPerSecond =
            min(maxVel, states[i].velocityMetersPerSecond);
      } else {
        states[i].curveRadius = radius;
        num maxVCurve = sqrt(maxAccel * radius.abs());
        states[i].velocityMetersPerSecond =
            min(maxVCurve, states[i].velocityMetersPerSecond);
      }
    }
  }

  static void calculateVelocity(
      List<TrajectoryState> states, List<Waypoint> pathPoints, num maxAccel) {
    if (pathPoints[0].velOverride == null) {
      states[0].velocityMetersPerSecond = 0;
      states[0].accelerationMetersPerSecondSq = maxAccel;
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

  static void recalculateValues(List<TrajectoryState> states, bool reversed) {
    for (int i = states.length - 1; i >= 0; i--) {
      TrajectoryState now = states[i];

      if (reversed) {
        now.velocityMetersPerSecond *= -1;
        now.accelerationMetersPerSecondSq *= -1;

        num h = now.headingRadians + pi;
        h = MathUtil.inputModulus(h, -pi, pi);
        now.headingRadians = h;
      }

      if (i != states.length - 1) {
        TrajectoryState next = states[i + 1];

        num dt = next.timeSeconds - now.timeSeconds;

        now.angularVelocity = MathUtil.inputModulus(
                next.headingRadians - now.headingRadians, -pi, pi) /
            dt;
        now.holonomicAngularVelocity = MathUtil.inputModulus(
                next.holonomicRotation - now.holonomicRotation, -180, 180) /
            dt;
      }

      if (now.curveRadius == double.infinity ||
          now.curveRadius == double.nan ||
          now.curveRadius == 0) {
        now.curvatureRadPerMeter = 0;
      } else {
        now.curvatureRadPerMeter = 1 / now.curveRadius;
      }
    }
  }

  static List<TrajectoryState> joinSplines(
      List<Waypoint> pathPoints, num maxVel, double step) {
    List<TrajectoryState> states = [];
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

        TrajectoryState state = TrajectoryState();
        state.translationMeters = p;

        num? startRot = startPoint.holonomicAngle;
        num? endRot = endPoint.holonomicAngle;

        int startSearchOffset = 0;
        int endSearchOffset = 0;

        while (startRot == null || endRot == null) {
          if (startRot == null) {
            startSearchOffset++;
            startRot = pathPoints[i - startSearchOffset].holonomicAngle;
          }
          if (endRot == null) {
            endSearchOffset++;
            endRot = pathPoints[i + 1 + endSearchOffset].holonomicAngle;
          }
        }

        num deltaRot = endRot - startRot;
        deltaRot = MathUtil.inputModulus(deltaRot, -180, 180);

        int startRotIndex = i - startSearchOffset;
        int endRotIndex = i + 1 + endSearchOffset;
        int rotRange = endRotIndex - startRotIndex;

        num holonomicRot = MathUtil.cosineInterpolate(startRot,
            startRot + deltaRot, ((i + t) - startRotIndex) / rotRange);
        holonomicRot = MathUtil.inputModulus(holonomicRot, -180, 180);
        state.holonomicRotation = holonomicRot;

        if (i > 0 || t > 0) {
          TrajectoryState s1 = states[states.length - 1];
          TrajectoryState s2 = state;
          double hypot = s1.translationMeters.distanceTo(s2.translationMeters);
          state.deltaPos = hypot;

          num heading = atan2(s1.translationMeters.y - s2.translationMeters.y,
                  s1.translationMeters.x - s2.translationMeters.x) +
              pi;
          heading = MathUtil.inputModulus(heading, -pi, pi);
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

  static num calculateRadius(
      TrajectoryState s0, TrajectoryState s1, TrajectoryState s2) {
    num ab = s0.translationMeters.distanceTo(s1.translationMeters);
    num bc = s1.translationMeters.distanceTo(s2.translationMeters);
    num ac = s0.translationMeters.distanceTo(s2.translationMeters);

    Point vba = s0.translationMeters - s1.translationMeters;
    Point vbc = s2.translationMeters - s1.translationMeters;
    num crossZ = (vba.x * vbc.y) - (vba.y * vbc.x);
    num sign = (crossZ < 0) ? 1 : -1;

    num p = (ab + bc + ac) / 2;
    num area = sqrt((p * (p - ab) * (p - bc) * (p - ac)).abs());
    return sign * (ab * bc * ac) / (4 * area);
  }
}

class TrajectoryState {
  num timeSeconds = 0.0;
  num velocityMetersPerSecond = 0.0;
  num accelerationMetersPerSecondSq = 0.0;
  Point translationMeters = const Point(0, 0);
  num headingRadians = 0.0;
  num curvatureRadPerMeter = 0.0;
  num angularVelocity = 0.0;
  num holonomicRotation = 0.0;
  num holonomicAngularVelocity = 0.0;

  num curveRadius = 0.0;
  num deltaPos = 0.0;

  TrajectoryState interpolate(TrajectoryState endVal, num t) {
    TrajectoryState lerpedState = TrajectoryState();

    lerpedState.timeSeconds =
        GeometryUtil.numLerp(timeSeconds, endVal.timeSeconds, t);
    num deltaT = lerpedState.timeSeconds - timeSeconds;

    if (deltaT < 0) {
      return endVal.interpolate(this, 1 - t);
    }

    lerpedState.velocityMetersPerSecond = GeometryUtil.numLerp(
        velocityMetersPerSecond, endVal.velocityMetersPerSecond, t);
    lerpedState.accelerationMetersPerSecondSq = GeometryUtil.numLerp(
        accelerationMetersPerSecondSq, endVal.accelerationMetersPerSecondSq, t);
    lerpedState.translationMeters =
        GeometryUtil.pointLerp(translationMeters, endVal.translationMeters, t);
    lerpedState.headingRadians =
        GeometryUtil.rotationLerp(headingRadians, endVal.headingRadians, t, pi);
    lerpedState.curvatureRadPerMeter = GeometryUtil.numLerp(
        curvatureRadPerMeter, endVal.curvatureRadPerMeter, t);
    lerpedState.angularVelocity =
        GeometryUtil.numLerp(angularVelocity, endVal.angularVelocity, t);
    lerpedState.holonomicRotation = GeometryUtil.rotationLerp(
        holonomicRotation, endVal.holonomicRotation, t, 180);
    lerpedState.holonomicAngularVelocity = GeometryUtil.numLerp(
        holonomicAngularVelocity, endVal.holonomicAngularVelocity, t);
    lerpedState.curveRadius =
        GeometryUtil.numLerp(curveRadius, endVal.curveRadius, t);
    lerpedState.deltaPos = GeometryUtil.numLerp(deltaPos, endVal.deltaPos, t);

    return lerpedState;
  }

  Map<String, dynamic> toJson() {
    return {
      'time': timeSeconds,
      'pose': {
        'rotation': {
          'radians': headingRadians,
        },
        'translation': {
          'x': translationMeters.x,
          'y': translationMeters.y,
        },
      },
      'velocity': velocityMetersPerSecond,
      'acceleration': accelerationMetersPerSecondSq,
      'curvature': curvatureRadPerMeter.isFinite ? curvatureRadPerMeter : 0,
      'holonomicRotation': holonomicRotation,
      'angularVelocity': angularVelocity,
      'holonomicAngularVelocity': holonomicAngularVelocity,
    };
  }

  String toCSV() {
    return '$timeSeconds,${translationMeters.x},${translationMeters.y},${GeometryUtil.toDegrees(headingRadians)},$velocityMetersPerSecond,$accelerationMetersPerSecondSq,$curvatureRadPerMeter,$holonomicRotation,${GeometryUtil.toDegrees(angularVelocity)},$holonomicAngularVelocity';
  }

  static String getCSVHeader() {
    return '# PathPlanner CSV Format:\n# timeSeconds, xPositionMeters, yPositionMeters, headingDegrees, velocityMetersPerSecond, accelerationMetersPerSecondSq, curvatureRadPerMeter, holonomicRotationDegrees, angularVelocityDegreesPerSec, holonomicAngularVelocityDegreesPerSec';
  }
}
