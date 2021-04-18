import 'dart:math';

class RobotPath {
  List<Waypoint> waypoints;

  RobotPath(this.waypoints);
}

class Waypoint {
  Point anchorPoint;
  Point prevControl;
  Point nextControl;

  Waypoint({this.anchorPoint, this.prevControl, this.nextControl});

  bool isStartPoint() {
    return prevControl == null;
  }

  bool isEndPoint() {
    return nextControl == null;
  }
}
