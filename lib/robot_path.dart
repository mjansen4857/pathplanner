import 'dart:math';

import 'package:pathplanner/services/undo_redo.dart';
import 'package:undo/undo.dart';

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

  void addWaypoint(Point anchorPos) {
    waypoints[waypoints.length - 1].addNextControl();
    waypoints.add(
      Waypoint(
        prevControl:
            (waypoints[waypoints.length - 1].nextControl + anchorPos) * 0.5,
        anchorPoint: anchorPos,
      ),
    );
  }

  static Waypoint cloneWaypoint(Waypoint w) {
    Point anchor = Point(w.anchorPoint.x, w.anchorPoint.y);
    Point prev =
        w.prevControl == null ? null : Point(w.prevControl.x, w.prevControl.y);
    Point next =
        w.nextControl == null ? null : Point(w.nextControl.x, w.nextControl.y);

    return Waypoint(
      anchorPoint: anchor,
      prevControl: prev,
      nextControl: next,
      holonomicAngle: w.holonomicAngle,
      isReversal: w.isReversal,
      velOverride: w.velOverride,
      isLocked: w.isLocked,
    );
  }

  static List<Waypoint> cloneWaypointList(List<Waypoint> waypoints) {
    List<Waypoint> points = [];

    for (Waypoint w in waypoints) {
      points.add(cloneWaypoint(w));
    }

    return points;
  }
}

class Waypoint {
  Point anchorPoint;
  Point prevControl;
  Point nextControl;
  double holonomicAngle;
  bool isReversal;
  double velOverride;
  bool isLocked;

  bool _isAnchorDragging = false;
  bool _isNextControlDragging = false;
  bool _isPrevControlDragging = false;
  bool _isHolonomicThingDragging = false;

  Waypoint(
      {this.anchorPoint,
      this.prevControl,
      this.nextControl,
      this.holonomicAngle = 0,
      this.isReversal = false,
      this.isLocked = false,
      this.velOverride}) {
    if (isReversal) {
      nextControl = prevControl;
    }
  }

  void move(double x, double y) {
    double dx = x - anchorPoint.x;
    double dy = y - anchorPoint.y;
    anchorPoint = Point(x, y);
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

  bool isPointInHolonomicThing(
      double xPos, double yPos, double radius, double robotLength) {
    double angle = -holonomicAngle / 180 * pi;
    double thingX = anchorPoint.x + (robotLength / 2 * cos(angle));
    double thingY = anchorPoint.y + (robotLength / 2 * sin(angle));
    return pow(xPos - thingX, 2) + pow(yPos - thingY, 2) < pow(radius, 2);
  }

  bool startDragging(
      double xPos,
      double yPos,
      double anchorRadius,
      double controlRadius,
      double holonomicThingRadius,
      double robotLength,
      bool holonomicMode) {
    if (isPointInAnchor(xPos, yPos, anchorRadius)) {
      return _isAnchorDragging = true;
    } else if (isPointInNextControl(xPos, yPos, controlRadius)) {
      return _isNextControlDragging = true;
    } else if (isPointInPrevControl(xPos, yPos, controlRadius)) {
      return _isPrevControlDragging = true;
    } else if (isPointInHolonomicThing(
            xPos, yPos, holonomicThingRadius, robotLength) &&
        holonomicMode) {
      return _isHolonomicThingDragging = true;
    }
    return false;
  }

  void dragUpdate(double x, double y) {
    if (_isAnchorDragging && !isLocked) {
      move(x, y);
    } else if (_isNextControlDragging) {
      if (isLocked) {
        Point lineEnd = nextControl + (nextControl - anchorPoint);
        Point newPoint = _closestPointOnLine(anchorPoint, lineEnd, Point(x, y));
        if (newPoint.x - anchorPoint.x != 0 ||
            newPoint.y - anchorPoint.y != 0) {
          nextControl = newPoint;
        }
      } else {
        nextControl = Point(x, y);
      }

      if (isReversal) {
        prevControl = nextControl;
      } else {
        updatePrevControlFromNext();
      }
    } else if (_isPrevControlDragging) {
      if (isLocked) {
        Point lineEnd = prevControl + (prevControl - anchorPoint);
        Point newPoint = _closestPointOnLine(anchorPoint, lineEnd, Point(x, y));
        if (newPoint.x - anchorPoint.x != 0 ||
            newPoint.y - anchorPoint.y != 0) {
          prevControl = newPoint;
        }
      } else {
        prevControl = Point(x, y);
      }

      if (isReversal) {
        nextControl = prevControl;
      } else {
        updateNextControlFromPrev();
      }
    } else if (_isHolonomicThingDragging && !isLocked) {
      double rotation = -atan2(y - anchorPoint.y, x - anchorPoint.x);
      holonomicAngle = (rotation * 180 / pi);
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

  void addNextControl() {
    var dst = anchorPoint.distanceTo(prevControl);
    var dir = (anchorPoint - prevControl);
    var mag = dir.magnitude;
    dir = Point(dir.x / mag, dir.y / mag);

    var control = Point(dir.x * dst, dir.y * dst);
    nextControl = Point(anchorPoint.x + control.x, anchorPoint.y + control.y);
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
    if (nextControl != null && !isReversal) {
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
    _isHolonomicThingDragging = false;
  }

  Point _closestPointOnLine(Point lineStart, Point lineEnd, Point p) {
    double dx = lineEnd.x - lineStart.x;
    double dy = lineEnd.y - lineStart.y;

    if (dx == 0 || dy == 0) {
      return lineStart;
    }

    double t = ((p.x - lineStart.x) * dx + (p.y - lineStart.y) * dy) /
        (dx * dx + dy * dy);

    Point closestPoint;
    if (t < 0) {
      closestPoint = lineStart;
    } else if (t > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = lineStart + ((lineEnd - lineStart) * t);
    }
    return closestPoint;
  }
}
