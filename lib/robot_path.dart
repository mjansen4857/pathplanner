import 'dart:math';

class RobotPath {
  List<Waypoint> waypoints;

  RobotPath(this.waypoints);
}

class Waypoint {
  Point anchorPoint;
  Point prevControl;
  Point nextControl;

  bool _isAnchorDragging = false;
  bool _isNextControlDragging = false;
  bool _isPrevControlDragging = false;

  Waypoint({this.anchorPoint, this.prevControl, this.nextControl});

  bool isStartPoint() {
    return prevControl == null;
  }

  bool isEndPoint() {
    return nextControl == null;
  }

  double getAngleRadians() {
    if (isStartPoint()) {
      return -atan2(
          nextControl.y - anchorPoint.y, nextControl.x - anchorPoint.x);
    } else {
      return -atan2(
          anchorPoint.y - prevControl.y, anchorPoint.x - prevControl.x);
    }
  }

  bool isPointInAnchor(double xPos, double yPos, double radius) {
    return pow(xPos - anchorPoint.x, 2) + pow(yPos - anchorPoint.y, 2) <
        pow(radius, 2);
  }

  bool isPointInNextControl(double xPos, double yPos, double radius) {
    if (nextControl != null) {
      return pow(xPos - nextControl.x, 2) + pow(yPos - nextControl.y, 2) <
          pow(radius, 2);
    }
    return false;
  }

  bool isPointInPrevControl(double xPos, double yPos, double radius) {
    if (prevControl != null) {
      return pow(xPos - prevControl.x, 2) + pow(yPos - prevControl.y, 2) <
          pow(radius, 2);
    }
    return false;
  }

  bool startDragging(
      double xPos, double yPos, double anchorRadius, double controlRadius) {
    if (isPointInAnchor(xPos, yPos, anchorRadius)) {
      return _isAnchorDragging = true;
    } else if (isPointInNextControl(xPos, yPos, controlRadius)) {
      return _isNextControlDragging = true;
    } else if (isPointInPrevControl(xPos, yPos, controlRadius)) {
      return _isPrevControlDragging = true;
    }
    return false;
  }

  void dragUpdate(double dx, double dy) {
    if (_isAnchorDragging) {
      anchorPoint = Point(anchorPoint.x + dx, anchorPoint.y + dy);
      if (nextControl != null) {
        nextControl = Point(nextControl.x + dx, nextControl.y + dy);
      }
      if (prevControl != null) {
        prevControl = Point(prevControl.x + dx, prevControl.y + dy);
      }
    } else if (_isNextControlDragging) {
      nextControl = Point(nextControl.x + dx, nextControl.y + dy);

      if (prevControl != null) {
        var dst = anchorPoint.distanceTo(prevControl);
        var dir =
            Point(anchorPoint.x - nextControl.x, anchorPoint.y - nextControl.y);
        var mag = dir.distanceTo(Point(0, 0));
        dir = Point(dir.x / mag, dir.y / mag);

        var control = Point(dir.x * dst, dir.y * dst);
        prevControl =
            Point(anchorPoint.x + control.x, anchorPoint.y + control.y);
      }
    } else if (_isPrevControlDragging) {
      prevControl = Point(prevControl.x + dx, prevControl.y + dy);

      if (nextControl != null) {
        var dst = anchorPoint.distanceTo(nextControl);
        var dir =
            Point(anchorPoint.x - prevControl.x, anchorPoint.y - prevControl.y);
        var mag = dir.distanceTo(Point(0, 0));
        dir = Point(dir.x / mag, dir.y / mag);

        var control = Point(dir.x * dst, dir.y * dst);
        nextControl =
            Point(anchorPoint.x + control.x, anchorPoint.y + control.y);
      }
    }
  }

  void stopDragging() {
    _isPrevControlDragging = false;
    _isNextControlDragging = false;
    _isAnchorDragging = false;
  }
}
