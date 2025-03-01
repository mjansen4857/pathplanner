import 'dart:collection';
import 'dart:math';

import 'package:pathplanner/util/wpimath/geometry.dart';

class Waypoint {
  static const num minControlLength = 0.25;
  static HashMap<String, Pose2d> linked = HashMap();

  Translation2d anchor;
  Translation2d? prevControl;
  Translation2d? nextControl;
  bool isLocked;
  String? linkedName;

  bool _isAnchorDragging = false;
  bool _isPrevControlDragging = false;
  bool _isNextControlDragging = false;

  Waypoint({
    required this.anchor,
    this.prevControl,
    this.nextControl,
    this.isLocked = false,
    this.linkedName,
  }) {
    // Set the lengths to their current length to enforce minimum
    if (prevControl != null) {
      setPrevControlLength(prevControlLength!);
    }
    if (nextControl != null) {
      setNextControlLength(nextControlLength!);
    }
  }

  bool get isAnchorDragging => _isAnchorDragging;

  Waypoint.fromJson(Map<String, dynamic> json)
      : this(
          anchor: Translation2d.fromJson(json['anchor']),
          prevControl:
              json['prevControl'] != null ? Translation2d.fromJson(json['prevControl']) : null,
          nextControl:
              json['nextControl'] != null ? Translation2d.fromJson(json['nextControl']) : null,
          isLocked: json['isLocked'] ?? false,
          linkedName: json['linkedName'],
        );

  Map<String, dynamic> toJson() {
    return {
      'anchor': anchor.toJson(),
      'prevControl': prevControl?.toJson(),
      'nextControl': nextControl?.toJson(),
      'isLocked': isLocked,
      'linkedName': linkedName,
    };
  }

  Rotation2d get heading =>
      (nextControl != null) ? (nextControl! - anchor).angle : (anchor - prevControl!).angle;

  bool get isStartPoint => prevControl == null;

  bool get isEndPoint => nextControl == null;

  num? get prevControlLength => prevControl?.getDistance(anchor);

  num? get nextControlLength => nextControl?.getDistance(anchor);

  void move(num x, num y) {
    num dx = x - anchor.x;
    num dy = y - anchor.y;
    anchor = Translation2d(x, y);
    if (nextControl != null) {
      nextControl = Translation2d(nextControl!.x + dx, nextControl!.y + dy);
    }
    if (prevControl != null) {
      prevControl = Translation2d(prevControl!.x + dx, prevControl!.y + dy);
    }

    if (linkedName != null) {
      linked[linkedName!] = Pose2d(anchor, linked[linkedName!]?.rotation ?? const Rotation2d());
    }
  }

  Waypoint clone() {
    return Waypoint(
      anchor: anchor,
      prevControl: prevControl,
      nextControl: nextControl,
      isLocked: isLocked,
      linkedName: linkedName,
    );
  }

  Waypoint reverse() {
    Translation2d anchorPt = Translation2d(17.55 - anchor.x, 8.05 - anchor.y);
    Translation2d? prev =
        prevControl == null ? null : Translation2d(17.55 - prevControl!.x, 8.05 - prevControl!.y);
    Translation2d? next =
        nextControl == null ? null : Translation2d(17.55 - nextControl!.x, 8.05 - nextControl!.y);

    return Waypoint(
      anchor: anchorPt,
      prevControl: prev,
      nextControl: next,
      linkedName: linkedName,
    );
  }

  Waypoint reverseH() {
    Translation2d anchorPt = Translation2d(anchor.x, 8.05 - anchor.y);
    Translation2d? prev =
        prevControl == null ? null : Translation2d(prevControl!.x, 8.05 - prevControl!.y);
    Translation2d? next =
        nextControl == null ? null : Translation2d(nextControl!.x, 8.05 - nextControl!.y);

    return Waypoint(
      anchor: anchorPt,
      prevControl: prev,
      nextControl: next,
      linkedName: linkedName,
    );
  }

  void setHeading(Rotation2d heading) {
    if (prevControl != null) {
      prevControl = anchor - Translation2d.fromAngle(prevControlLength!, heading);
    }
    if (nextControl != null) {
      nextControl = anchor + Translation2d.fromAngle(nextControlLength!, heading);
    }
  }

  void addNextControl() {
    if (prevControl != null) {
      nextControl =
          anchor + Translation2d.fromAngle(prevControlLength!, (anchor - prevControl!).angle);
    }
  }

  void setPrevControlLength(num length) {
    if (prevControl != null) {
      if (!length.isFinite) {
        length = minControlLength;
      }
      length = max(length, minControlLength);
      prevControl = anchor + Translation2d.fromAngle(length, (prevControl! - anchor).angle);
    }
  }

  void setNextControlLength(num length) {
    if (nextControl != null) {
      if (!length.isFinite) {
        length = minControlLength;
      }
      length = max(length, minControlLength);
      nextControl = anchor + Translation2d.fromAngle(length, (nextControl! - anchor).angle);
    }
  }

  bool isPointInAnchor(num xPos, num yPos, num radius) {
    return pow(xPos - anchor.x, 2) + pow(yPos - anchor.y, 2) < pow(radius, 2);
  }

  bool isPointInNextControl(num xPos, num yPos, num radius) {
    if (nextControl != null) {
      return pow(xPos - nextControl!.x, 2) + pow(yPos - nextControl!.y, 2) < pow(radius, 2);
    }
    return false;
  }

  bool isPointInPrevControl(num xPos, num yPos, num radius) {
    if (prevControl != null) {
      return pow(xPos - prevControl!.x, 2) + pow(yPos - prevControl!.y, 2) < pow(radius, 2);
    }
    return false;
  }

  bool startDragging(num xPos, num yPos, num anchorRadius, num controlRadius) {
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
        Translation2d lineEnd = nextControl! + (nextControl! - anchor);
        Translation2d newPoint = _closestPointOnLine(anchor, lineEnd, Translation2d(x, y));
        if (newPoint.x - anchor.x != 0 || newPoint.y - anchor.y != 0) {
          nextControl = newPoint;
        }
      } else {
        nextControl = Translation2d(x, y);
      }

      if (prevControl != null) {
        prevControl =
            anchor + Translation2d.fromAngle(prevControlLength!, (anchor - nextControl!).angle);
      }
      // Set the length to enforce minimum
      setNextControlLength(nextControlLength!);
    } else if (_isPrevControlDragging) {
      if (isLocked) {
        Translation2d lineEnd = prevControl! + (prevControl! - anchor);
        Translation2d newPoint = _closestPointOnLine(anchor, lineEnd, Translation2d(x, y));
        if (newPoint.x - anchor.x != 0 || newPoint.y - anchor.y != 0) {
          prevControl = newPoint;
        }
      } else {
        prevControl = Translation2d(x, y);
      }

      if (nextControl != null) {
        nextControl =
            anchor + Translation2d.fromAngle(nextControlLength!, (anchor - prevControl!).angle);
      }
      // Set the length to enforce minimum
      setPrevControlLength(prevControlLength!);
    }
  }

  void stopDragging() {
    _isPrevControlDragging = false;
    _isNextControlDragging = false;
    _isAnchorDragging = false;
  }

  Translation2d _closestPointOnLine(
      Translation2d lineStart, Translation2d lineEnd, Translation2d p) {
    var dx = lineEnd.x - lineStart.x;
    var dy = lineEnd.y - lineStart.y;

    if (dx == 0 || dy == 0) {
      return lineStart;
    }

    num t = ((p.x - lineStart.x) * dx + (p.y - lineStart.y) * dy) / (dx * dx + dy * dy);

    Translation2d closestPoint;
    if (t < 0) {
      closestPoint = lineStart;
    } else if (t > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = lineStart.interpolate(lineEnd, t);
    }
    return closestPoint;
  }

  @override
  bool operator ==(Object other) =>
      other is Waypoint &&
      other.runtimeType == runtimeType &&
      other.anchor == anchor &&
      other.prevControl == prevControl &&
      other.nextControl == nextControl &&
      other.linkedName == linkedName;

  @override
  int get hashCode => Object.hash(anchor, prevControl, nextControl, linkedName);
}
