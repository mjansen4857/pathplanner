import 'dart:math';

import 'package:pathplanner/services/simulator/chassis_speeds.dart';

class ChassisSpeedsLimiter {
  num translationLimit;
  num rotationLimit;

  final ChassisSpeeds _prevVal;

  ChassisSpeedsLimiter(
      {required this.translationLimit,
      required this.rotationLimit,
      ChassisSpeeds? initialValue})
      : _prevVal = initialValue ?? ChassisSpeeds();

  void setRateLimits(num translationLimit, num rotationLimit) {
    this.translationLimit = translationLimit;
    this.rotationLimit = rotationLimit;
  }

  ChassisSpeeds calculate(ChassisSpeeds input, num elapsedTime) {
    _prevVal.omega += (input.omega - _prevVal.omega)
        .clamp(-rotationLimit * elapsedTime, rotationLimit * elapsedTime);

    _Vector2 prevVelVec = _Vector2(_prevVal.vx, _prevVal.vy);
    _Vector2 targetVelVec = _Vector2(input.vx, input.vy);
    _Vector2 deltaVelVec = targetVelVec - prevVelVec;
    num maxDelta = translationLimit * elapsedTime;

    if (deltaVelVec.norm() > maxDelta) {
      _Vector2 deltaUnitVec = deltaVelVec / deltaVelVec.norm();
      _Vector2 limitedDelta = deltaUnitVec * maxDelta;
      _Vector2 nextVelVector = prevVelVec + limitedDelta;

      _prevVal.vx = nextVelVector.x;
      _prevVal.vy = nextVelVector.y;
    } else {
      _prevVal.vx = targetVelVec.x;
      _prevVal.vy = targetVelVec.y;
    }

    return _prevVal;
  }
}

class _Vector2 {
  final num x;
  final num y;

  const _Vector2(this.x, this.y);

  num norm() {
    return sqrt(pow(x, 2) + pow(y, 2));
  }

  _Vector2 operator +(_Vector2 other) => _Vector2(x + other.x, y + other.y);

  _Vector2 operator -(_Vector2 other) => _Vector2(x - other.x, y - other.y);

  _Vector2 operator *(num d) => _Vector2(x * d, y * d);

  _Vector2 operator /(num d) => _Vector2(x / d, y / d);
}
