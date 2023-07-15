import 'dart:math';

class Waypoint {
  Point anchor;
  Point? prevControl;
  Point? nextControl;
  bool isLocked;

  bool _isAnchorDragging = false;
  bool _isPrevControlDragging = false;
  bool _isNextControlDragging = false;

  Waypoint({
    required this.anchor,
    this.prevControl,
    this.nextControl,
    this.isLocked = false,
  });

  num getHeadingRadians() {
    num heading;
    if (nextControl != null) {
      heading = atan2(nextControl!.y - anchor.y, nextControl!.x - anchor.x);
    } else {
      heading = atan2(anchor.y - prevControl!.y, anchor.x - prevControl!.x);
    }
    if (heading == -0) return 0;
    return heading;
  }

  num getHeadingDegrees() {
    return getHeadingRadians() * 180 / pi;
  }

  num getPrevControlLength() {
    if (prevControl == null) {
      return 0;
    }

    return anchor.distanceTo(prevControl!);
  }

  num getNextControlLength() {
    if (nextControl == null) {
      return 0;
    }

    return anchor.distanceTo(nextControl!);
  }

  void move(num x, num y) {
    num dx = x - anchor.x;
    num dy = y - anchor.y;
    anchor = Point(x, y);
    if (nextControl != null) {
      nextControl = Point(nextControl!.x + dx, nextControl!.y + dy);
    }
    if (prevControl != null) {
      prevControl = Point(prevControl!.x + dx, prevControl!.y + dy);
    }
  }

  Waypoint clone() {
    Point anchorPt = Point(anchor.x, anchor.y);
    Point? prev =
        prevControl == null ? null : Point(prevControl!.x, prevControl!.y);
    Point? next =
        nextControl == null ? null : Point(nextControl!.x, nextControl!.y);

    return Waypoint(
      anchor: anchorPt,
      prevControl: prev,
      nextControl: next,
    );
  }

  void setHeading(num headingDegrees) {
    var theta = headingDegrees * pi / 180;
    if (nextControl != null) {
      var h = (anchor - nextControl!).magnitude;
      var o = sin(theta) * h;
      var a = cos(theta) * h;

      nextControl = anchor + Point(a, o);
      updatePrevControlFromNext();
    } else if (prevControl != null) {
      var h = (anchor - prevControl!).magnitude;
      var o = sin(theta) * h;
      var a = cos(theta) * h;

      prevControl = anchor - Point(a, o);
      updateNextControlFromPrev();
    }
  }

  void updatePrevControlFromNext() {
    if (prevControl != null) {
      var dst = anchor.distanceTo(prevControl!);
      var dir = anchor - nextControl!;
      var mag = dir.magnitude;
      dir = Point(dir.x / mag, dir.y / mag);

      var control = Point(dir.x * dst, dir.y * dst);
      prevControl = Point(anchor.x + control.x, anchor.y + control.y);
    }
  }

  void updateNextControlFromPrev() {
    if (nextControl != null) {
      var dst = anchor.distanceTo(nextControl!);
      var dir = (anchor - prevControl!);
      var mag = dir.magnitude;
      dir = Point(dir.x / mag, dir.y / mag);

      var control = Point(dir.x * dst, dir.y * dst);
      nextControl = Point(anchor.x + control.x, anchor.y + control.y);
    }
  }

  void addNextControl() {
    var dst = anchor.distanceTo(prevControl!);
    var dir = (anchor - prevControl!);
    var mag = dir.magnitude;
    dir = Point(dir.x / mag, dir.y / mag);

    var control = Point(dir.x * dst, dir.y * dst);
    nextControl = Point(anchor.x + control.x, anchor.y + control.y);
  }

  void setPrevControlLength(num length) {
    if (prevControl != null) {
      var dir = prevControl! - anchor;
      var mag = dir.magnitude;
      dir = Point(dir.x / mag, dir.y / mag);

      var control = Point(dir.x * length, dir.y * length);
      prevControl = Point(anchor.x + control.x, anchor.y + control.y);
    }
  }

  void setNextControlLength(num length) {
    if (nextControl != null) {
      var dir = nextControl! - anchor;
      var mag = dir.magnitude;
      dir = Point(dir.x / mag, dir.y / mag);

      var control = Point(dir.x * length, dir.y * length);
      nextControl = Point(anchor.x + control.x, anchor.y + control.y);
    }
  }

  bool isPointInAnchor(num xPos, num yPos, num radius) {
    return pow(xPos - anchor.x, 2) + pow(yPos - anchor.y, 2) < pow(radius, 2);
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

  bool startDragging(num xPos, num yPos, num anchorRadius, num controlRadius,
      num holonomicThingRadius) {
    if (isPointInAnchor(xPos, yPos, anchorRadius)) {
      return _isAnchorDragging = true;
    } else if (isPointInNextControl(xPos, yPos, controlRadius)) {
      return _isNextControlDragging = true;
    } else if (isPointInPrevControl(xPos, yPos, controlRadius)) {
      return _isPrevControlDragging = true;
    }
    return false;
  }

  void dragUpdate(num x, num y) {
    if (_isAnchorDragging && !isLocked) {
      move(x, y);
    } else if (_isNextControlDragging) {
      if (isLocked) {
        Point lineEnd = nextControl! + (nextControl! - anchor);
        Point newPoint = _closestPointOnLine(anchor, lineEnd, Point(x, y));
        if (newPoint.x - anchor.x != 0 || newPoint.y - anchor.y != 0) {
          nextControl = newPoint;
        }
      } else {
        nextControl = Point(x, y);
      }

      updatePrevControlFromNext();
    } else if (_isPrevControlDragging) {
      if (isLocked) {
        Point lineEnd = prevControl! + (prevControl! - anchor);
        Point newPoint = _closestPointOnLine(anchor, lineEnd, Point(x, y));
        if (newPoint.x - anchor.x != 0 || newPoint.y - anchor.y != 0) {
          prevControl = newPoint;
        }
      } else {
        prevControl = Point(x, y);
      }

      updateNextControlFromPrev();
    }
  }

  void stopDragging() {
    _isPrevControlDragging = false;
    _isNextControlDragging = false;
    _isAnchorDragging = false;
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
}
