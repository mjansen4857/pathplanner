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
}
