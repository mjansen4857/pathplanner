import 'dart:math';

import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/simulator/chassis_speeds.dart';
import 'package:pathplanner/services/simulator/rotation_controller.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/math_util.dart';

class TrajectoryGenerator {}

class Trajectory {
  final List<TrajectoryState> states;

  Trajectory(PathPlannerPath path, ChassisSpeeds startingSpeeds,
      num maxModuleSpeed, num driveBaseRadius,
      [num startingRotationRadians = 0, num startingAngVelRps = 0])
      : states = _generateStates(path, startingSpeeds) {
    _simulateRotation(startingRotationRadians, startingAngVelRps,
        maxModuleSpeed, driveBaseRadius);
  }

  TrajectoryState sample(num time) {
    if (time <= states.first.time) return states.first;
    if (time >= states.last.time) return states.last;

    int low = 1;
    int high = states.length - 1;

    while (low != high) {
      int mid = ((low + high) / 2).floor();
      if (states[mid].time < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    TrajectoryState sample = states[low];
    TrajectoryState prevSample = states[low - 1];

    if ((sample.time - prevSample.time).abs() < 1E-3) return sample;

    return prevSample.interpolate(
        sample, (time - prevSample.time) / (sample.time - prevSample.time));
  }

  void _simulateRotation(num startingRotationRadians, num startingAngVelRps,
      num maxModuleSpeed, num driveBaseRadius) {
    num mpsToRps = 1.0 / driveBaseRadius;

    RotationController controller = RotationController(
        setpoint: State(
            position: startingRotationRadians, velocity: startingAngVelRps));

    states.first.holonomicRotationRadians = startingRotationRadians;

    for (int i = 1; i < states.length; i++) {
      num angVelConstraint =
          GeometryUtil.toRadians(states[i].constraints.maxAngularVelocity);

      // Approximation of available module speed to do rotation with
      num maxAngVelModule =
          max(0, maxModuleSpeed - states[i].velocity) * mpsToRps;
      num maxAngVel = min(angVelConstraint, maxAngVelModule);

      num dt = states[i].time - states[i - 1].time;
      num rot = controller.calculate(
          states[i - 1].holonomicRotationRadians,
          states[i].holonomicRotationRadians,
          maxAngVel,
          GeometryUtil.toRadians(states[i].constraints.maxAngularAcceleration),
          dt);

      states[i].holonomicRotationRadians = MathUtil.inputModulus(rot, -pi, pi);
    }
  }

  static int _getNextRotationTargetIdx(
      PathPlannerPath path, int startingIndex) {
    int idx = path.pathPoints.length - 1;

    for (int i = startingIndex; i < path.pathPoints.length - 2; i++) {
      if (path.pathPoints[i].holonomicRotation != null) {
        idx = i;
        break;
      }
    }

    return idx;
  }

  static List<TrajectoryState> _generateStates(
      PathPlannerPath path, ChassisSpeeds startingSpeeds) {
    List<TrajectoryState> states = [];

    num startVel = sqrt(pow(startingSpeeds.vx, 2) + pow(startingSpeeds.vy, 2));

    int nextRotationTargetIdx = _getNextRotationTargetIdx(path, 0);

    // Initial pass. Creates all states and handles linear acceleration
    for (int i = 0; i < path.pathPoints.length; i++) {
      TrajectoryState state = TrajectoryState();

      PathConstraints constraints = path.pathPoints[i].constraints;
      state.constraints = constraints;

      if (i > nextRotationTargetIdx) {
        nextRotationTargetIdx = _getNextRotationTargetIdx(path, i);
      }

      state.holonomicRotationRadians = GeometryUtil.toRadians(
          path.pathPoints[nextRotationTargetIdx].holonomicRotation!);

      state.position = path.pathPoints[i].position;

      if (i == path.pathPoints.length - 1) {
        state.headingRadians = states[states.length - 1].headingRadians;
        state.deltaPos = path.pathPoints[i].distanceAlongPath -
            path.pathPoints[i - 1].distanceAlongPath;
        state.velocity = path.goalEndState.velocity;
      } else if (i == 0) {
        Point delta = path.pathPoints[i + 1].position - state.position;
        state.headingRadians = atan2(delta.y, delta.x);
        state.deltaPos = 0;
        state.velocity = startVel;
      } else {
        Point delta = path.pathPoints[i + 1].position - state.position;
        state.headingRadians = atan2(delta.y, delta.x);
        state.deltaPos = path.pathPoints[i + 1].distanceAlongPath -
            path.pathPoints[i].distanceAlongPath;

        num v0 = states[states.length - 1].velocity;
        num vMax = sqrt(
            (pow(v0, 2) + (2 * constraints.maxAcceleration * state.deltaPos))
                .abs());
        state.velocity = min(vMax, path.pathPoints[i].maxV);
      }

      states.add(state);
    }

    // Second pass. Handles linear deceleration
    for (int i = states.length - 2; i > 1; i--) {
      PathConstraints constraints = states[i].constraints;

      num v0 = states[i + 1].velocity;

      num vMax = sqrt(pow(v0, 2) +
          (2 * constraints.maxAcceleration * states[i + 1].deltaPos).abs());
      states[i].velocity = min(vMax, states[i].velocity);
    }

    // Final pass. Calculates time, linear acceleration, and angular velocity
    num time = 0;
    states.first.time = 0;

    for (int i = 1; i < states.length; i++) {
      num v0 = states[i - 1].velocity;
      num v = states[i].velocity;
      num dt = (2 * states[i].deltaPos) / (v + v0);

      time += dt;
      states[i].time = time;
    }

    return states;
  }
}

class TrajectoryState {
  num time = 0;
  num velocity = 0;

  Point position = const Point(0, 0);
  num headingRadians = 0;

  num holonomicRotationRadians = 0;
  PathConstraints constraints = PathConstraints();

  num deltaPos = 0;

  TrajectoryState();

  TrajectoryState interpolate(TrajectoryState endVal, num t) {
    TrajectoryState lerpedState = TrajectoryState();

    lerpedState.time = GeometryUtil.numLerp(time, endVal.time, t);
    num deltaT = lerpedState.time - time;

    if (deltaT < 0) {
      return endVal.interpolate(this, 1 - t);
    }

    lerpedState.velocity = GeometryUtil.numLerp(velocity, endVal.velocity, t);
    lerpedState.position = GeometryUtil.pointLerp(position, endVal.position, t);
    lerpedState.headingRadians =
        GeometryUtil.rotationLerp(headingRadians, endVal.headingRadians, t, pi);
    lerpedState.deltaPos = GeometryUtil.numLerp(deltaPos, endVal.deltaPos, t);
    lerpedState.holonomicRotationRadians = GeometryUtil.rotationLerp(
        holonomicRotationRadians, endVal.holonomicRotationRadians, t, pi);

    if (t < 0.5) {
      lerpedState.constraints = constraints;
    } else {
      lerpedState.constraints = endVal.constraints;
    }

    return lerpedState;
  }
}
