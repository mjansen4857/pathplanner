import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path.dart';
import 'package:pathplanner/widgets/path_editor/waypoint_card.dart';

class PathEditor extends StatefulWidget {
  final RobotPath path;
  Waypoint _draggedPoint;
  Waypoint _selectedPoint;

  PathEditor(this.path);

  @override
  _PathEditorState createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: GestureDetector(
            onTapDown: (details) {
              FocusScopeNode currentScope = FocusScope.of(context);
              if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
                FocusManager.instance.primaryFocus.unfocus();
              }
              for (Waypoint w in widget.path.waypoints.reversed) {
                if (w.isPointInAnchor(
                        xPixelsToMeters(details.localPosition.dx),
                        yPixelsToMeters(details.localPosition.dy),
                        pixelsToMeters(8)) ||
                    w.isPointInNextControl(
                        xPixelsToMeters(details.localPosition.dx),
                        yPixelsToMeters(details.localPosition.dy),
                        pixelsToMeters(6)) ||
                    w.isPointInPrevControl(
                        xPixelsToMeters(details.localPosition.dx),
                        yPixelsToMeters(details.localPosition.dy),
                        pixelsToMeters(6))) {
                  setState(() {
                    widget._selectedPoint = w;
                  });
                  return;
                }
              }
              setState(() {
                widget._selectedPoint = null;
              });
            },
            onPanStart: (details) {
              for (Waypoint w in widget.path.waypoints.reversed) {
                if (w.startDragging(
                    xPixelsToMeters(details.localPosition.dx),
                    yPixelsToMeters(details.localPosition.dy),
                    pixelsToMeters(8),
                    pixelsToMeters(6))) {
                  widget._draggedPoint = w;
                  break;
                }
              }
            },
            onPanUpdate: (details) {
              if (widget._draggedPoint != null) {
                setState(() {
                  widget._draggedPoint.dragUpdate(
                      pixelsToMeters(details.delta.dx),
                      pixelsToMeters(-details.delta.dy));
                });
              }
            },
            onPanEnd: (details) {
              if (widget._draggedPoint != null) {
                widget._draggedPoint.stopDragging();
                widget._draggedPoint = null;
              }
            },
            child: Container(
              child: Stack(
                children: [
                  Image(image: AssetImage('images/field20.png')),
                  Positioned.fill(
                    child: Container(
                      constraints:
                          BoxConstraints(maxWidth: 1200, maxHeight: 600),
                      child: CustomPaint(
                        painter: PathPainter(widget.path,
                            selectedWaypoint: widget._selectedPoint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: FractionalOffset.topRight,
          child: WaypointCard(
            widget._selectedPoint,
            label: widget.path.getWaypointLabel(widget._selectedPoint),
            onXPosUpdate: (newVal) {
              if (newVal != null) {
                setState(() {
                  widget._selectedPoint
                      .move(newVal - widget._selectedPoint.anchorPoint.x, 0);
                });
              }
            },
            onYPosUpdate: (newVal) {
              if (newVal != null) {
                setState(() {
                  widget._selectedPoint
                      .move(0, newVal - widget._selectedPoint.anchorPoint.y);
                });
              }
            },
            onHeadingUpdate: (newVal) {
              if (newVal != null) {
                setState(() {
                  widget._selectedPoint.setHeading(newVal);
                });
              }
            },
          ),
        ),
      ],
    );
  }

  double xPixelsToMeters(double pixels) {
    return (pixels - 76) / 66.11 / PathPainter.scale;
  }

  double yPixelsToMeters(double pixels) {
    return (600 - pixels - 78) / 66.11 / PathPainter.scale;
  }

  double pixelsToMeters(double pixels) {
    return pixels / 66.11 / PathPainter.scale;
  }
}

class PathPainter extends CustomPainter {
  var defaultSize = Size(1200, 600);
  var robotSize = Size(0.75, 0.75);
  static double scale = 1;
  RobotPath path;
  Waypoint selectedWaypoint;

  PathPainter(this.path, {this.selectedWaypoint});

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / defaultSize.width;

    paintCenterPath(canvas, scale);
    // paintDualPaths(canvas, scale);

    for (Waypoint w in path.waypoints) {
      paintRobotOutline(canvas, scale, w);
      paintWaypoint(canvas, scale, w);
    }
  }

  void paintCenterPath(Canvas canvas, double scale) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]
      ..strokeWidth = 2;

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      Path p = Path();
      Offset p0 = pointToPixelOffset(path.waypoints[i].anchorPoint, scale);
      Offset p1 = pointToPixelOffset(path.waypoints[i].nextControl, scale);
      Offset p2 = pointToPixelOffset(path.waypoints[i + 1].prevControl, scale);
      Offset p3 = pointToPixelOffset(path.waypoints[i + 1].anchorPoint, scale);
      p.moveTo(p0.dx, p0.dy);
      p.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

      canvas.drawPath(p, paint);
    }
  }

  // no worky. would have to make custom bezier drawing
  void paintDualPaths(Canvas canvas, double scale) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]
      ..strokeWidth = 2;

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      Path p = Path();

      double angle1 = path.waypoints[i].getHeadingRadians();
      double angle2 = path.waypoints[i + 1].getHeadingRadians();
      double halfWidth = metersToPixels(robotSize.width / 2, scale);

      Offset p0L = pointToPixelOffset(path.waypoints[i].anchorPoint, scale)
          .translate(halfWidth * sin(angle1), -(halfWidth * cos(angle1)));
      Offset p1L = pointToPixelOffset(path.waypoints[i].nextControl, scale)
          .translate(halfWidth * sin(angle1), -(halfWidth * cos(angle1)));
      Offset p2L = pointToPixelOffset(path.waypoints[i + 1].prevControl, scale)
          .translate(halfWidth * sin(angle2), -(halfWidth * cos(angle2)));
      Offset p3L = pointToPixelOffset(path.waypoints[i + 1].anchorPoint, scale)
          .translate(halfWidth * sin(angle2), -(halfWidth * cos(angle2)));

      Offset p0R = pointToPixelOffset(path.waypoints[i].anchorPoint, scale)
          .translate(-(halfWidth * sin(angle1)), halfWidth * cos(angle1));
      Offset p1R = pointToPixelOffset(path.waypoints[i].nextControl, scale)
          .translate(-(halfWidth * sin(angle1)), halfWidth * cos(angle1));
      Offset p2R = pointToPixelOffset(path.waypoints[i + 1].prevControl, scale)
          .translate(-(halfWidth * sin(angle2)), halfWidth * cos(angle2));
      Offset p3R = pointToPixelOffset(path.waypoints[i + 1].anchorPoint, scale)
          .translate(-(halfWidth * sin(angle2)), halfWidth * cos(angle2));

      p.moveTo(p0L.dx, p0L.dy);
      p.cubicTo(p1L.dx, p1L.dy, p2L.dx, p2L.dy, p3L.dx, p3L.dy);

      p.moveTo(p0R.dx, p0R.dy);
      p.cubicTo(p1R.dx, p1R.dy, p2R.dx, p2R.dy, p3R.dx, p3R.dy);

      canvas.drawPath(p, paint);
    }
  }

  void paintRobotOutline(Canvas canvas, double scale, Waypoint waypoint) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[400]
      ..strokeWidth = 2;

    if (waypoint == selectedWaypoint) {
      paint.color = Colors.orange;
    }

    Offset center = pointToPixelOffset(waypoint.anchorPoint, scale);
    double angle = waypoint.getHeadingRadians();
    double halfWidth = metersToPixels(robotSize.width / 2, scale);
    double halfLength = metersToPixels(robotSize.height / 2, scale);

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
  }

  void paintWaypoint(Canvas canvas, double scale, Waypoint waypoint) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 2;

    //draw control point lines
    if (waypoint.nextControl != null) {
      canvas.drawLine(pointToPixelOffset(waypoint.anchorPoint, scale),
          pointToPixelOffset(waypoint.nextControl, scale), paint);
    }
    if (waypoint.prevControl != null) {
      canvas.drawLine(pointToPixelOffset(waypoint.anchorPoint, scale),
          pointToPixelOffset(waypoint.prevControl, scale), paint);
    }

    if (waypoint.isStartPoint()) {
      paint.color = Colors.green;
    } else if (waypoint.isEndPoint()) {
      paint.color = Colors.red;
    } else {
      paint.color = Colors.grey[300];
    }

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        pointToPixelOffset(waypoint.anchorPoint, scale), 8 * scale, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        pointToPixelOffset(waypoint.anchorPoint, scale), 8 * scale, paint);

    // draw control points
    if (waypoint.nextControl != null) {
      paint.style = PaintingStyle.fill;
      paint.color = Colors.grey[300];

      canvas.drawCircle(
          pointToPixelOffset(waypoint.nextControl, scale), 6 * scale, paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          pointToPixelOffset(waypoint.nextControl, scale), 6 * scale, paint);
    }
    if (waypoint.prevControl != null) {
      paint.style = PaintingStyle.fill;
      paint.color = Colors.grey[300];

      canvas.drawCircle(
          pointToPixelOffset(waypoint.prevControl, scale), 6 * scale, paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          pointToPixelOffset(waypoint.prevControl, scale), 6 * scale, paint);
    }
  }

  Offset pointToPixelOffset(Point point, double scale) {
    return Offset((point.x * 66.11) + 76,
            defaultSize.height - ((point.y * 66.11) + 78))
        .scale(scale, scale);
  }

  double metersToPixels(double meters, double scale) {
    return meters * 66.11 * scale;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
