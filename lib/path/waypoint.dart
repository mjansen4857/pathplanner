import 'dart:math';

class Waypoint {
  Point anchor;
  Point? prevControl;
  Point? nextControl;
  bool isReversal;
  bool isStopPoint;
  bool isLocked;

  Waypoint({
    required this.anchor,
    this.prevControl,
    this.nextControl,
    this.isReversal = false,
    this.isStopPoint = false,
    this.isLocked = false,
  });
}
