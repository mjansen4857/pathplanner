import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/path_editor/waypoint_card.dart';
import 'package:undo/undo.dart';

class PathEditor extends StatefulWidget {
  final RobotPath path;
  Waypoint _draggedPoint;
  Waypoint _selectedPoint;
  double robotWidth;
  double robotLength;
  bool holonomicMode;
  Waypoint _dragOldValue;

  PathEditor(this.path, this.robotWidth, this.robotLength, this.holonomicMode);

  @override
  _PathEditorState createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  @override
  Widget build(BuildContext context) {
    return KeyBoardShortcuts(
      keysToPress: {
        (Platform.isMacOS)
            ? LogicalKeyboardKey.meta
            : LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyZ
      },
      onKeysPressed: () {
        setState(() {
          widget._selectedPoint = null;
        });
        UndoRedo.undo();
      },
      child: KeyBoardShortcuts(
        keysToPress: {
          (Platform.isMacOS)
              ? LogicalKeyboardKey.meta
              : LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyY
        },
        onKeysPressed: () {
          setState(() {
            widget._selectedPoint = null;
          });
          UndoRedo.redo();
        },
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                onDoubleTapDown: (details) {
                  UndoRedo.addChange(Change(
                    RobotPath.cloneWaypointList(widget.path.waypoints),
                    () {
                      setState(() {
                        widget.path.addWaypoint(Point(
                            xPixelsToMeters(details.localPosition.dx),
                            yPixelsToMeters(details.localPosition.dy)));
                      });
                    },
                    (oldValue) {
                      setState(() {
                        widget.path.waypoints =
                            RobotPath.cloneWaypointList(oldValue);
                      });
                    },
                  ));
                  setState(() {
                    widget._selectedPoint =
                        widget.path.waypoints[widget.path.waypoints.length - 1];
                  });
                },
                onDoubleTap: () {},
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
                            pixelsToMeters(6)) ||
                        w.isPointInHolonomicThing(
                            xPixelsToMeters(details.localPosition.dx),
                            yPixelsToMeters(details.localPosition.dy),
                            pixelsToMeters(5),
                            widget.robotLength)) {
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
                        pixelsToMeters(6),
                        pixelsToMeters(5),
                        widget.robotLength,
                        widget.holonomicMode)) {
                      widget._draggedPoint = w;
                      widget._dragOldValue = RobotPath.cloneWaypoint(w);
                      break;
                    }
                  }
                },
                onPanUpdate: (details) {
                  if (widget._draggedPoint != null) {
                    setState(() {
                      widget._draggedPoint.dragUpdate(
                          xPixelsToMeters(details.localPosition.dx),
                          yPixelsToMeters(details.localPosition.dy));
                    });
                  }
                },
                onPanEnd: (details) {
                  if (widget._draggedPoint != null) {
                    widget._draggedPoint.stopDragging();
                    int index =
                        widget.path.waypoints.indexOf(widget._draggedPoint);
                    Waypoint dragEnd =
                        RobotPath.cloneWaypoint(widget._draggedPoint);
                    UndoRedo.addChange(Change(
                      widget._dragOldValue,
                      () {
                        setState(() {
                          if (widget.path.waypoints[index] !=
                              widget._draggedPoint) {
                            widget.path.waypoints[index] =
                                RobotPath.cloneWaypoint(dragEnd);
                          }
                        });
                      },
                      (oldValue) {
                        setState(() {
                          widget.path.waypoints[index] =
                              RobotPath.cloneWaypoint(oldValue);
                        });
                      },
                    ));
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
                            painter: PathPainter(
                                widget.path,
                                Size(widget.robotWidth, widget.robotLength),
                                widget.holonomicMode,
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
                holonomicEnabled: widget.holonomicMode,
                deleteEnabled: widget.path.waypoints.length > 2,
                onDelete: () {
                  int delIndex =
                      widget.path.waypoints.indexOf(widget._selectedPoint);
                  UndoRedo.addChange(Change(
                    RobotPath.cloneWaypointList(widget.path.waypoints),
                    () {
                      setState(() {
                        Waypoint w = widget.path.waypoints.removeAt(delIndex);
                        if (w.isEndPoint()) {
                          widget
                              .path
                              .waypoints[widget.path.waypoints.length - 1]
                              .nextControl = null;
                          widget
                              .path
                              .waypoints[widget.path.waypoints.length - 1]
                              .isReversal = false;
                        } else if (w.isStartPoint()) {
                          widget.path.waypoints[0].prevControl = null;
                          widget.path.waypoints[0].isReversal = false;
                        }
                      });
                    },
                    (oldValue) {
                      setState(() {
                        widget.path.waypoints =
                            RobotPath.cloneWaypointList(oldValue);
                      });
                    },
                  ));
                  setState(() {
                    widget._selectedPoint = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double xPixelsToMeters(double pixels) {
    return ((pixels / PathPainter.scale) - 76) / 66.11;
  }

  double yPixelsToMeters(double pixels) {
    return (600 - (pixels / PathPainter.scale) - 78) / 66.11;
  }

  double pixelsToMeters(double pixels) {
    return pixels / 66.11 / PathPainter.scale;
  }
}

class PathPainter extends CustomPainter {
  var defaultSize = Size(1200, 600);
  var robotSize;
  bool holonomicMode;
  static double scale = 1;
  RobotPath path;
  Waypoint selectedWaypoint;

  PathPainter(this.path, this.robotSize, this.holonomicMode,
      {this.selectedWaypoint});

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / defaultSize.width;

    if (holonomicMode) {
      paintCenterPath(canvas, scale);
    } else {
      paintDualPaths(canvas, scale);
    }

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

  void paintDualPaths(Canvas canvas, double scale) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]
      ..strokeWidth = 2;

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      Path p = Path();

      double halfWidth = metersToPixels(robotSize.width / 2, scale);

      Offset p0 = pointToPixelOffset(path.waypoints[i].anchorPoint, scale);
      Offset p1 = pointToPixelOffset(path.waypoints[i].nextControl, scale);
      Offset p2 = pointToPixelOffset(path.waypoints[i + 1].prevControl, scale);
      Offset p3 = pointToPixelOffset(path.waypoints[i + 1].anchorPoint, scale);

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

  void paintRobotOutline(Canvas canvas, double scale, Waypoint waypoint) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]
      ..strokeWidth = 2;

    if (waypoint == selectedWaypoint) {
      paint.color = Colors.orange;
    }

    Offset center = pointToPixelOffset(waypoint.anchorPoint, scale);
    double angle = (holonomicMode)
        ? ((waypoint.holonomicAngle ?? 0) / 180 * pi)
        : waypoint.getHeadingRadians();
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

    if (holonomicMode) {
      Offset frontMiddle = frontLeft + ((frontRight - frontLeft) * 0.5);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(frontMiddle, 5, paint);
    }
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
