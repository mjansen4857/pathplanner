import 'dart:math';

class RobotPath {
  List<Waypoint> waypoints;
  String name;

  RobotPath(this.waypoints, {this.name = 'New Path'});

  String getWaypointLabel(Waypoint waypoint) {
    if (waypoint == null) return null;
    if (waypoint.isStartPoint()) return 'Start Point';
    if (waypoint.isEndPoint()) return 'End Point';

    return 'Waypoint ' + waypoints.indexOf(waypoint).toString();
  }
}

class Waypoint {
  Point anchorPoint;
  Point prevControl;
  Point nextControl;
  double holonomicAngle;
  bool isReversal;
  double velOverride;

  bool _isAnchorDragging = false;
  bool _isNextControlDragging = false;
  bool _isPrevControlDragging = false;

  Waypoint(
      {this.anchorPoint,
      this.prevControl,
      this.nextControl,
      this.holonomicAngle = 0,
      this.isReversal = false,
      this.velOverride}) {
    if (isReversal) {
      nextControl = prevControl;
    }
  }

  void move(double dx, double dy) {
    anchorPoint = Point(anchorPoint.x + dx, anchorPoint.y + dy);
    if (nextControl != null) {
      nextControl = Point(nextControl.x + dx, nextControl.y + dy);
    }
    if (prevControl != null) {
      prevControl = Point(prevControl.x + dx, prevControl.y + dy);
    }
  }

  double getXPos() {
    return anchorPoint.x;
  }

  double getYPos() {
    return anchorPoint.y;
  }

  bool isStartPoint() {
    return prevControl == null;
  }

  bool isEndPoint() {
    return nextControl == null;
  }

  double getHeadingRadians() {
    var heading;
    if (isStartPoint()) {
      heading =
          -atan2(nextControl.y - anchorPoint.y, nextControl.x - anchorPoint.x);
    } else {
      heading =
          -atan2(anchorPoint.y - prevControl.y, anchorPoint.x - prevControl.x);
    }
    if (heading == -0) return 0;
    return heading;
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
      move(dx, dy);
    } else if (_isNextControlDragging) {
      nextControl = Point(nextControl.x + dx, nextControl.y + dy);
      if (isReversal) {
        prevControl = nextControl;
      } else {
        updatePrevControlFromNext();
      }
    } else if (_isPrevControlDragging) {
      prevControl = Point(prevControl.x + dx, prevControl.y + dy);
      if (isReversal) {
        nextControl = prevControl;
      } else {
        updateNextControlFromPrev();
      }
    }
  }

  void updatePrevControlFromNext() {
    if (prevControl != null) {
      var dst = anchorPoint.distanceTo(prevControl);
      var dir = anchorPoint - nextControl;
      var mag = dir.magnitude;
      dir = Point(dir.x / mag, dir.y / mag);

      var control = Point(dir.x * dst, dir.y * dst);
      prevControl = Point(anchorPoint.x + control.x, anchorPoint.y + control.y);
    }
  }

  void updateNextControlFromPrev() {
    if (nextControl != null) {
      var dst = anchorPoint.distanceTo(nextControl);
      var dir = (anchorPoint - prevControl);
      var mag = dir.magnitude;
      dir = Point(dir.x / mag, dir.y / mag);

      var control = Point(dir.x * dst, dir.y * dst);
      nextControl = Point(anchorPoint.x + control.x, anchorPoint.y + control.y);
    }
  }

  void setReversal(bool reversal) {
    this.isReversal = reversal;
    if (reversal) {
      nextControl = prevControl;
    } else {
      updateNextControlFromPrev();
    }
  }

  void setHeading(double headingDegrees) {
    var theta = -headingDegrees * pi / 180;
    if (nextControl != null) {
      var h = (anchorPoint - nextControl).magnitude;
      var o = sin(theta) * h;
      var a = cos(theta) * h;

      nextControl = anchorPoint + Point(a, o);
      if (isReversal) {
        prevControl = nextControl;
      } else {
        updatePrevControlFromNext();
      }
    } else if (prevControl != null) {
      var h = (anchorPoint - prevControl).magnitude;
      var o = sin(theta) * h;
      var a = cos(theta) * h;

      prevControl = anchorPoint - Point(a, o);
      if (isReversal) {
        nextControl = prevControl;
      } else {
        updateNextControlFromPrev();
      }
    }
  }

  void stopDragging() {
    _isPrevControlDragging = false;
    _isNextControlDragging = false;
    _isAnchorDragging = false;
  }
}
