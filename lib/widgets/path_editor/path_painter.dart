import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/generator/trajectory.dart';
import 'package:pathplanner/widgets/path_editor/path_editor.dart';

class PathPainter extends CustomPainter {
  final Size _defaultSize = Size(1200, 600);
  final Size _robotSize;
  final bool _holonomicMode;
  final RobotPath _path;
  final Waypoint? _selectedWaypoint;
  final EditorMode _editorMode;
  Animation<num>? previewTime;

  static double scale = 1;

  PathPainter(this._path, this._robotSize, this._holonomicMode,
      this._selectedWaypoint, this._editorMode, Animation<double>? animation)
      : super(repaint: animation) {
    if (animation != null && _path.generatedTrajectory != null) {
      previewTime =
          Tween<num>(begin: 0, end: _path.generatedTrajectory!.getRuntime())
              .animate(animation);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / _defaultSize.width;

    switch (_editorMode) {
      case EditorMode.Edit:
        if (_holonomicMode) {
          _paintCenterPath(canvas, scale, Colors.grey[300]!);
        } else {
          _paintDualPaths(canvas, scale);
        }

        for (Waypoint w in _path.waypoints) {
          _paintRobotOutline(canvas, scale, w);
          _paintWaypoint(canvas, scale, w);
        }
        break;
      case EditorMode.Preview:
        _paintCenterPath(canvas, scale, Colors.grey[700]!);
        if (_path.generatedTrajectory != null && previewTime != null) {
          _paintPreviewOutline(canvas, scale,
              _path.generatedTrajectory!.sample(previewTime!.value));
        }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  void _paintCenterPath(Canvas canvas, double scale, Color color) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    for (int i = 0; i < _path.waypoints.length - 1; i++) {
      Path p = Path();
      Offset p0 = _pointToPixelOffset(_path.waypoints[i].anchorPoint, scale);
      Offset p1 = _pointToPixelOffset(_path.waypoints[i].nextControl!, scale);
      Offset p2 =
          _pointToPixelOffset(_path.waypoints[i + 1].prevControl!, scale);
      Offset p3 =
          _pointToPixelOffset(_path.waypoints[i + 1].anchorPoint, scale);
      p.moveTo(p0.dx, p0.dy);
      p.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

      canvas.drawPath(p, paint);
    }
  }

  void _paintDualPaths(Canvas canvas, double scale) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]!
      ..strokeWidth = 2;

    for (int i = 0; i < _path.waypoints.length - 1; i++) {
      Path p = Path();

      double halfWidth = _metersToPixels(_robotSize.width / 2, scale);

      Offset p0 = _pointToPixelOffset(_path.waypoints[i].anchorPoint, scale);
      Offset p1 = _pointToPixelOffset(_path.waypoints[i].nextControl!, scale);
      Offset p2 =
          _pointToPixelOffset(_path.waypoints[i + 1].prevControl!, scale);
      Offset p3 =
          _pointToPixelOffset(_path.waypoints[i + 1].anchorPoint, scale);

      for (double t = 0; t < 1.0; t += 0.01) {
        Offset center = _cubicLerp(p0, p1, p2, p3, t);
        Offset centerNext = _cubicLerp(p0, p1, p2, p3, t + 0.01);

        double angle =
            atan2(centerNext.dy - center.dy, centerNext.dx - center.dx);

        Offset r =
            center.translate(-(halfWidth * sin(angle)), halfWidth * cos(angle));
        Offset rNext = centerNext.translate(
            -(halfWidth * sin(angle)), halfWidth * cos(angle));

        if (t == 0) {
          p.moveTo(r.dx, r.dy);
        }
        p.lineTo(rNext.dx, rNext.dy);
      }

      for (double t = 0; t < 1.0; t += 0.01) {
        Offset center = _cubicLerp(p0, p1, p2, p3, t);
        Offset centerNext = _cubicLerp(p0, p1, p2, p3, t + 0.01);

        double angle =
            atan2(centerNext.dy - center.dy, centerNext.dx - center.dx);

        Offset l =
            center.translate(halfWidth * sin(angle), -(halfWidth * cos(angle)));
        Offset lNext = centerNext.translate(
            halfWidth * sin(angle), -(halfWidth * cos(angle)));

        if (t == 0) {
          p.moveTo(l.dx, l.dy);
        }
        p.lineTo(lNext.dx, lNext.dy);
      }

      canvas.drawPath(p, paint);
    }
  }

  void _paintRobotOutline(Canvas canvas, double scale, Waypoint waypoint) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]!
      ..strokeWidth = 2;

    if (waypoint == _selectedWaypoint) {
      paint.color = Colors.orange;
    }

    Offset center = _pointToPixelOffset(waypoint.anchorPoint, scale);
    double angle = (_holonomicMode)
        ? (-waypoint.holonomicAngle / 180 * pi)
        : -waypoint.getHeadingRadians();
    double halfWidth = _metersToPixels(_robotSize.width / 2, scale);
    double halfLength = _metersToPixels(_robotSize.height / 2, scale);

    Offset l = Offset(center.dx + (halfWidth * sin(angle)),
        center.dy - (halfWidth * cos(angle)));
    Offset r = Offset(center.dx - (halfWidth * sin(angle)),
        center.dy + (halfWidth * cos(angle)));

    Offset frontLeft = Offset(
        l.dx + (halfLength * cos(angle)), l.dy + (halfLength * sin(angle)));
    Offset backLeft = Offset(
        l.dx - (halfLength * cos(angle)), l.dy - (halfLength * sin(angle)));
    Offset frontRight = Offset(
        r.dx + (halfLength * cos(angle)), r.dy + (halfLength * sin(angle)));
    Offset backRight = Offset(
        r.dx - (halfLength * cos(angle)), r.dy - (halfLength * sin(angle)));

    canvas.drawLine(backLeft, frontLeft, paint);
    canvas.drawLine(frontLeft, frontRight, paint);
    canvas.drawLine(frontRight, backRight, paint);
    canvas.drawLine(backRight, backLeft, paint);

    if (_holonomicMode) {
      Offset frontMiddle = frontLeft + ((frontRight - frontLeft) * 0.5);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(frontMiddle, 5, paint);
    }
  }

  void _paintPreviewOutline(
      Canvas canvas, double scale, TrajectoryState state) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]!
      ..strokeWidth = 2;

    Offset center = _pointToPixelOffset(state.translationMeters, scale);
    num angle = (_holonomicMode)
        ? (-state.holonomicRotation / 180 * pi)
        : -state.headingRadians;
    double halfWidth = _metersToPixels(_robotSize.width / 2, scale);
    double halfLength = _metersToPixels(_robotSize.height / 2, scale);

    Offset l = Offset(center.dx + (halfWidth * sin(angle)),
        center.dy - (halfWidth * cos(angle)));
    Offset r = Offset(center.dx - (halfWidth * sin(angle)),
        center.dy + (halfWidth * cos(angle)));

    Offset frontLeft = Offset(
        l.dx + (halfLength * cos(angle)), l.dy + (halfLength * sin(angle)));
    Offset backLeft = Offset(
        l.dx - (halfLength * cos(angle)), l.dy - (halfLength * sin(angle)));
    Offset frontRight = Offset(
        r.dx + (halfLength * cos(angle)), r.dy + (halfLength * sin(angle)));
    Offset backRight = Offset(
        r.dx - (halfLength * cos(angle)), r.dy - (halfLength * sin(angle)));

    canvas.drawLine(backLeft, frontLeft, paint);
    canvas.drawLine(frontLeft, frontRight, paint);
    canvas.drawLine(frontRight, backRight, paint);
    canvas.drawLine(backRight, backLeft, paint);

    Offset frontMiddle = frontLeft + ((frontRight - frontLeft) * 0.5);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(frontMiddle, 5, paint);
  }

  void _paintWaypoint(Canvas canvas, double scale, Waypoint waypoint) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 2;

    //draw control point lines
    if (waypoint.nextControl != null) {
      canvas.drawLine(_pointToPixelOffset(waypoint.anchorPoint, scale),
          _pointToPixelOffset(waypoint.nextControl!, scale), paint);
    }
    if (waypoint.prevControl != null) {
      canvas.drawLine(_pointToPixelOffset(waypoint.anchorPoint, scale),
          _pointToPixelOffset(waypoint.prevControl!, scale), paint);
    }

    if (waypoint.isStartPoint()) {
      paint.color = Colors.green;
    } else if (waypoint.isEndPoint()) {
      paint.color = Colors.red;
    } else {
      paint.color = Colors.grey[300]!;
    }

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        _pointToPixelOffset(waypoint.anchorPoint, scale), 8 * scale, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        _pointToPixelOffset(waypoint.anchorPoint, scale), 8 * scale, paint);

    // draw control points
    if (waypoint.nextControl != null) {
      paint.style = PaintingStyle.fill;
      paint.color = Colors.grey[300]!;

      canvas.drawCircle(
          _pointToPixelOffset(waypoint.nextControl!, scale), 6 * scale, paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          _pointToPixelOffset(waypoint.nextControl!, scale), 6 * scale, paint);
    }
    if (waypoint.prevControl != null) {
      paint.style = PaintingStyle.fill;
      paint.color = Colors.grey[300]!;

      canvas.drawCircle(
          _pointToPixelOffset(waypoint.prevControl!, scale), 6 * scale, paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          _pointToPixelOffset(waypoint.prevControl!, scale), 6 * scale, paint);
    }
  }

  Offset _pointToPixelOffset(Point point, double scale) {
    return Offset((point.x * 66.11) + 76,
            _defaultSize.height - ((point.y * 66.11) + 78))
        .scale(scale, scale);
  }

  double _metersToPixels(double meters, double scale) {
    return meters * 66.11 * scale;
  }

  Offset _lerp(Offset a, Offset b, double t) {
    return a + ((b - a) * t);
  }

  Offset _quadraticLerp(Offset a, Offset b, Offset c, double t) {
    Offset p0 = _lerp(a, b, t);
    Offset p1 = _lerp(b, c, t);
    return _lerp(p0, p1, t);
  }

  Offset _cubicLerp(Offset a, Offset b, Offset c, Offset d, double t) {
    Offset p0 = _quadraticLerp(a, b, c, t);
    Offset p1 = _quadraticLerp(b, c, d, t);
    return _lerp(p0, p1, t);
  }
}
