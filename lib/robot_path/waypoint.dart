import 'dart:math';

import 'package:pathplanner/robot_path/stop_event.dart';

class Waypoint {
  Point anchorPoint;
  Point? prevControl;
  Point? nextControl;
  num? holonomicAngle;
  bool isReversal;
  num? velOverride;
  bool isLocked;
  bool isStopPoint;
  StopEvent stopEvent;

  bool _isAnchorDragging = false;
  bool _isNextControlDragging = false;
  bool _isPrevControlDragging = false;
  bool _isHolonomicThingDragging = false;

  Waypoint({
    required this.anchorPoint,
    this.prevControl,
    this.nextControl,
    this.holonomicAngle = 0,
    this.isReversal = false,
    this.isLocked = false,
    this.velOverride,
    this.isStopPoint = false,
    required this.stopEvent,
  }) {
    if (isReversal) {
      nextControl = prevControl;
    }
  }

  Waypoint clone() {
    Point anchor = Point(anchorPoint.x, anchorPoint.y);
    Point? prev =
        prevControl == null ? null : Point(prevControl!.x, prevControl!.y);
    Point? next =
        nextControl == null ? null : Point(nextControl!.x, nextControl!.y);

    return Waypoint(
      anchorPoint: anchor,
      prevControl: prev,
      nextControl: next,
      holonomicAngle: holonomicAngle,
      isReversal: isReversal,
      velOverride: velOverride,
      isLocked: isLocked,
      isStopPoint: isStopPoint,
      stopEvent: stopEvent.clone(),
    );
  }

  void move(num x, num y) {
    num dx = x - anchorPoint.x;
    num dy = y - anchorPoint.y;
    anchorPoint = Point(x, y);
    if (nextControl != null) {
      nextControl = Point(nextControl!.x + dx, nextControl!.y + dy);
    }
    if (prevControl != null) {
      prevControl = Point(prevControl!.x + dx, prevControl!.y + dy);
    }
  }

  num getXPos() {
    return anchorPoint.x;
  }

  num getYPos() {
    return anchorPoint.y;
  }

  bool isStartPoint() {
    return prevControl == null;
  }

  bool isEndPoint() {
    return nextControl == null;
  }

  num getHeadingRadians() {
    num heading;
    if (isStartPoint()) {
      heading =
          atan2(nextControl!.y - anchorPoint.y, nextControl!.x - anchorPoint.x);
    } else {
      heading =
          atan2(anchorPoint.y - prevControl!.y, anchorPoint.x - prevControl!.x);
    }
    if (heading == -0) return 0;
    return heading;
  }

  num getHeadingDegrees() {
    return getHeadingRadians() * 180 / pi;
  }

  bool isPointInAnchor(num xPos, num yPos, num radius) {
    return pow(xPos - anchorPoint.x, 2) + pow(yPos - anchorPoint.y, 2) <
        pow(radius, 2);
  }

  bool isPointInNextControl(num xPos, num yPos, num radius) {
    if (nextControl != null) {
      return pow(xPos - nextControl!.x, 2) + pow(yPos - nextControl!.y, 2) <
          pow(radius, 2);
    }
    return false;
  }

  bool isPointInPrevControl(num xPos, num yPos, num radius) {
    if (prevControl != null) {
      return pow(xPos - prevControl!.x, 2) + pow(yPos - prevControl!.y, 2) <
          pow(radius, 2);
    }
    return false;
  }

  bool isPointInHolonomicThing(
      num xPos, num yPos, num radius, num robotLength) {
    if (holonomicAngle == null) {
      return false;
    }
    num angle = holonomicAngle! / 180 * pi;
    num thingX = anchorPoint.x + (robotLength / 2 * cos(angle));
    num thingY = anchorPoint.y + (robotLength / 2 * sin(angle));
    return pow(xPos - thingX, 2) + pow(yPos - thingY, 2) < pow(radius, 2);
  }

  bool startDragging(num xPos, num yPos, num anchorRadius, num controlRadius,
      num holonomicThingRadius, num robotLength, bool holonomicMode) {
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

  void dragUpdate(num x, num y) {
    if (_isAnchorDragging && !isLocked) {
      move(x, y);
    } else if (_isNextControlDragging) {
      if (isLocked) {
        Point lineEnd = nextControl! + (nextControl! - anchorPoint);
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
        Point lineEnd = prevControl! + (prevControl! - anchorPoint);
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
      num rotation = atan2(y - anchorPoint.y, x - anchorPoint.x);
      holonomicAngle = (rotation * 180 / pi);
    }
  }

  void updatePrevControlFromNext() {
    if (prevControl != null) {
      var dst = anchorPoint.distanceTo(prevControl!);
      var dir = anchorPoint - nextControl!;
      var mag = dir.magnitude;
      dir = Point(dir.x / mag, dir.y / mag);

      var control = Point(dir.x * dst, dir.y * dst);
      prevControl = Point(anchorPoint.x + control.x, anchorPoint.y + control.y);
    }
  }

  void updateNextControlFromPrev() {
    if (nextControl != null) {
      var dst = anchorPoint.distanceTo(nextControl!);
      var dir = (anchorPoint - prevControl!);
      var mag = dir.magnitude;
      dir = Point(dir.x / mag, dir.y / mag);

      var control = Point(dir.x * dst, dir.y * dst);
      nextControl = Point(anchorPoint.x + control.x, anchorPoint.y + control.y);
    }
  }

  void addNextControl() {
    var dst = anchorPoint.distanceTo(prevControl!);
    var dir = (anchorPoint - prevControl!);
    var mag = dir.magnitude;
    dir = Point(dir.x / mag, dir.y / mag);

    var control = Point(dir.x * dst, dir.y * dst);
    nextControl = Point(anchorPoint.x + control.x, anchorPoint.y + control.y);
  }

  void setReversal(bool reversal) {
    isReversal = reversal;
    if (reversal) {
      nextControl = prevControl;
    } else {
      updateNextControlFromPrev();
    }
  }

  void setHeading(num headingDegrees) {
    var theta = headingDegrees * pi / 180;
    if (nextControl != null && !isReversal) {
      var h = (anchorPoint - nextControl!).magnitude;
      var o = sin(theta) * h;
      var a = cos(theta) * h;

      nextControl = anchorPoint + Point(a, o);
      if (isReversal) {
        prevControl = nextControl;
      } else {
        updatePrevControlFromNext();
      }
    } else if (prevControl != null) {
      var h = (anchorPoint - prevControl!).magnitude;
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
    var dx = lineEnd.x - lineStart.x;
    var dy = lineEnd.y - lineStart.y;

    if (dx == 0 || dy == 0) {
      return lineStart;
    }

    num t = ((p.x - lineStart.x) * dx + (p.y - lineStart.y) * dy) /
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

  Waypoint.fromJson(Map<String, dynamic> json)
      : anchorPoint = Point(json['anchorPoint']['x'], json['anchorPoint']['y']),
        prevControl = json['prevControl'] == null
            ? null
            : Point(json['prevControl']['x'], json['prevControl']['y']),
        nextControl = json['nextControl'] == null
            ? null
            : Point(json['nextControl']['x'], json['nextControl']['y']),
        holonomicAngle = json['holonomicAngle'],
        isReversal = json['isReversal'],
        velOverride = json['velOverride'],
        isLocked = json['isLocked'],
        isStopPoint = json['isStopPoint'] ?? false,
        stopEvent = StopEvent.fromJson(json['stopEvent'] ?? {}) {
    if ((isStartPoint() || isEndPoint() || isStopPoint) &&
        holonomicAngle == null) {
      holonomicAngle = 0;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'anchorPoint': {
        'x': anchorPoint.x,
        'y': anchorPoint.y,
      },
      'prevControl': prevControl == null
          ? null
          : {
              'x': prevControl!.x,
              'y': prevControl!.y,
            },
      'nextControl': nextControl == null
          ? null
          : {
              'x': nextControl!.x,
              'y': nextControl!.y,
            },
      'holonomicAngle': (isStartPoint() || isEndPoint() || isStopPoint) &&
              holonomicAngle == null
          ? 0.0
          : holonomicAngle,
      'isReversal': isReversal,
      'velOverride': velOverride,
      'isLocked': isLocked,
      'isStopPoint': isStopPoint,
      'stopEvent': stopEvent.toJson(),
    };
  }
}
