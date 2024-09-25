import 'dart:math';

class Units {
  static const num _rpmToRps = pi / (60.0 / 2.0);

  static num rotationsPerMinuteToRadiansPerSecond(num rpm) {
    return rpm * _rpmToRps;
  }
}
