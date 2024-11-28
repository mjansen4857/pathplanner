import 'dart:math';

class Units {
  static const num _rpmToRps = pi / (60.0 / 2.0);
  static const num _degToRads = pi / 180.0;
  static const num _radToDeg = 180 / pi;

  static num rpmToRadsPerSec(num rpm) {
    return rpm * _rpmToRps;
  }

  static num degreesToRadians(num degrees) {
    return degrees * _degToRads;
  }

  static num radiansToDegrees(num radians) {
    return radians * _radToDeg;
  }
}
