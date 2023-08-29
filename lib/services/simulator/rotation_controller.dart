import 'dart:math';

import 'package:pathplanner/util/math_util.dart';

class RotationController {
  State setpoint;

  RotationController({required this.setpoint});

  num calculate(
      num measurement, num goalPos, num maxVel, num maxAccel, num dt) {
    num goalMinDistance = MathUtil.inputModulus(goalPos - measurement, -pi, pi);
    num setpointMinDistance =
        MathUtil.inputModulus(setpoint.position - measurement, -pi, pi);

    goalPos = goalMinDistance + measurement;
    setpoint.position = setpointMinDistance + measurement;

    int direction = (setpoint.position > goalPos) ? -1 : 1;
    State current = State(
      position: setpoint.position * direction,
      velocity: setpoint.velocity * direction,
    );
    State goal = State(position: goalPos * direction);

    if (current.velocity > maxVel) {
      current.velocity = maxVel;
    }

    num cutoffBegin = current.velocity / maxAccel;
    num cutoffDistBegin = cutoffBegin * cutoffBegin * maxAccel / 2.0;

    num cutoffEnd = goal.velocity / maxAccel;
    num cutoffDistEnd = cutoffEnd * cutoffEnd * maxAccel / 2.0;

    num fullTrapezoidDist =
        cutoffDistBegin + (goal.position - current.position) + cutoffDistEnd;
    num accelerationTime = maxVel / maxAccel;

    num fullSpeedDist =
        fullTrapezoidDist - accelerationTime * accelerationTime * maxAccel;

    if (fullSpeedDist < 0) {
      accelerationTime = sqrt(fullTrapezoidDist / maxAccel);
      fullSpeedDist = 0;
    }

    num endAccel = accelerationTime - cutoffBegin;
    num endFullSpeed = endAccel + fullSpeedDist / maxVel;
    num endDeccel = endFullSpeed + accelerationTime - cutoffEnd;
    State result =
        State(position: current.position, velocity: current.velocity);

    if (dt < endAccel) {
      result.velocity += dt * maxAccel;
      result.position += (current.velocity + dt * maxAccel / 2.0) * dt;
    } else if (dt < endFullSpeed) {
      result.velocity = maxVel;
      result.position +=
          (current.velocity + endAccel * maxAccel / 2.0) * endAccel +
              maxVel * (dt - endAccel);
    } else if (dt <= endDeccel) {
      result.velocity = goal.velocity + (endDeccel - dt) * maxAccel;
      num timeLeft = endDeccel - dt;
      result.position = goal.position -
          (goal.velocity + timeLeft * maxAccel / 2.0) * timeLeft;
    } else {
      result = goal;
    }

    result.position *= direction;
    result.velocity *= direction;
    setpoint = result;

    return setpoint.position;
  }
}

class State {
  num position;
  num velocity;

  State({this.position = 0, this.velocity = 0});
}
