import 'dart:math';

class Waypoint {
  Point anchor;
  Point? prevControl;
  Point? nextControl;
  bool isLocked;

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
}
