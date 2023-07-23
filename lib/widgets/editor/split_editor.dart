import 'dart:math';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/prefs_keys.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/waypoints_tree.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class SplitEditor extends StatefulWidget {
  final SharedPreferences prefs;
  final PathPlannerPath path;
  final FieldImage fieldImage;

  const SplitEditor({
    required this.prefs,
    required this.path,
    required this.fieldImage,
    super.key,
  });

  @override
  State<SplitEditor> createState() => _SplitEditorState();
}

class _SplitEditorState extends State<SplitEditor> {
  final MultiSplitViewController _controller = MultiSplitViewController();
  final WaypointsTreeController _waypointsTreeController =
      WaypointsTreeController();
  int? _hoveredWaypoint;
  int? _selectedWaypoint;
  int? _hoveredZone;
  int? _selectedZone;
  int? _hoveredRotTarget;
  int? _selectedRotTarget;
  int? _hoveredMarker;
  int? _selectedMarker;
  late bool _treeOnRight;
  Waypoint? _draggedPoint;
  Waypoint? _dragOldValue;
  int? _draggedRotationIdx;
  num? _dragRotationOldValue;

  late Size _robotSize;

  List<Waypoint> get waypoints => widget.path.waypoints;

  @override
  void initState() {
    super.initState();

    _treeOnRight = widget.prefs.getBool(PrefsKeys.treeOnRight) ?? true;

    var width = widget.prefs.getDouble(PrefsKeys.robotWidth) ?? 0.75;
    var length = widget.prefs.getDouble(PrefsKeys.robotLength) ?? 1.0;
    _robotSize = Size(width, length);

    double treeWeight =
        widget.prefs.getDouble(PrefsKeys.editorTreeWeight) ?? 0.5;
    _controller.areas = [
      Area(
        weight: _treeOnRight ? (1.0 - treeWeight) : treeWeight,
        minimalWeight: 0.25,
      ),
      Area(
        weight: _treeOnRight ? treeWeight : (1.0 - treeWeight),
        minimalWeight: 0.25,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
              onDoubleTap: () {},
              onTapDown: (details) {
                FocusScopeNode currentScope = FocusScope.of(context);
                if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
                  FocusManager.instance.primaryFocus!.unfocus();
                }
                for (int i = waypoints.length - 1; i >= 0; i--) {
                  Waypoint w = waypoints[i];
                  if (w.isPointInAnchor(
                          _xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy),
                          _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                              25, _PathPainter.scale, widget.fieldImage))) ||
                      w.isPointInNextControl(
                          _xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy),
                          _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                              20, _PathPainter.scale, widget.fieldImage))) ||
                      w.isPointInPrevControl(
                          _xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy),
                          _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                              20, _PathPainter.scale, widget.fieldImage)))) {
                    _setSelectedWaypoint(i);
                    return;
                  }
                }
                _setSelectedWaypoint(null);
              },
              onDoubleTapDown: (details) {
                UndoRedo.addChange(Change(
                  PathPlannerPath.cloneWaypoints(waypoints),
                  () {
                    setState(() {
                      widget.path.addWaypoint(Point(
                          _xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy)));
                      widget.path.generateAndSavePath();
                    });
                  },
                  (oldValue) {
                    setState(() {
                      widget.path.waypoints =
                          PathPlannerPath.cloneWaypoints(oldValue);
                      _setSelectedWaypoint(null);
                      widget.path.generateAndSavePath();
                    });
                  },
                ));
              },
              onPanStart: (details) {
                double xPos = _xPixelsToMeters(details.localPosition.dx);
                double yPos = _yPixelsToMeters(details.localPosition.dy);

                for (int i = waypoints.length - 1; i >= 0; i--) {
                  Waypoint w = waypoints[i];
                  if (w.startDragging(
                      xPos,
                      yPos,
                      _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                          25, _PathPainter.scale, widget.fieldImage)),
                      _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                          20, _PathPainter.scale, widget.fieldImage)))) {
                    _draggedPoint = w;
                    _dragOldValue = w.clone();
                    break;
                  }
                }

                // Not dragging any waypoints, check rotations
                num dotRadius = _pixelsToMeters(
                    PathPainterUtil.uiPointSizeToPixels(
                        15, _PathPainter.scale, widget.fieldImage));
                // This is a little bit stupid but whatever
                for (int i = -1; i < widget.path.rotationTargets.length; i++) {
                  num rotation;
                  Point pos;
                  if (i == -1) {
                    rotation = widget.path.goalEndState.rotation;
                    pos = widget.path.waypoints.last.anchor;
                  } else {
                    rotation = widget.path.rotationTargets[i].rotationDegrees;
                    int pointIdx =
                        (widget.path.rotationTargets[i].waypointRelativePos /
                                0.05)
                            .round();
                    pos = widget.path.pathPoints[pointIdx].position;
                  }

                  num angleRadians = rotation / 180.0 * pi;
                  num dotX =
                      pos.x + (_robotSize.height / 2 * cos(angleRadians));
                  num dotY =
                      pos.y + (_robotSize.height / 2 * sin(angleRadians));
                  if (pow(xPos - dotX, 2) + pow(yPos - dotY, 2) <
                      pow(dotRadius, 2)) {
                    _draggedRotationIdx = i;
                    _dragRotationOldValue = rotation;
                  }
                }
              },
              onPanUpdate: (details) {
                if (_draggedPoint != null) {
                  setState(() {
                    _draggedPoint!.dragUpdate(
                        _xPixelsToMeters(min(
                            88 +
                                (widget.fieldImage.defaultSize.width *
                                    _PathPainter.scale),
                            max(8, details.localPosition.dx))),
                        _yPixelsToMeters(min(
                            88 +
                                (widget.fieldImage.defaultSize.height *
                                    _PathPainter.scale),
                            max(8, details.localPosition.dy))));
                    widget.path.generatePathPoints();
                  });
                } else if (_draggedRotationIdx != null) {
                  Point pos;
                  if (_draggedRotationIdx == -1) {
                    pos = widget.path.waypoints.last.anchor;
                  } else {
                    int pointIdx = (widget
                                .path
                                .rotationTargets[_draggedRotationIdx!]
                                .waypointRelativePos /
                            0.05)
                        .round();
                    pos = widget.path.pathPoints[pointIdx].position;
                  }

                  double x = _xPixelsToMeters(details.localPosition.dx);
                  double y = _yPixelsToMeters(details.localPosition.dy);
                  num rotation = atan2(y - pos.y, x - pos.x);
                  num rotationDeg = (rotation * 180 / pi);

                  setState(() {
                    if (_draggedRotationIdx == -1) {
                      widget.path.goalEndState.rotation = rotationDeg;
                    } else {
                      widget.path.rotationTargets[_draggedRotationIdx!]
                          .rotationDegrees = rotationDeg;
                    }
                  });
                }
              },
              onPanEnd: (details) {
                if (_draggedPoint != null) {
                  _draggedPoint!.stopDragging();
                  int index = waypoints.indexOf(_draggedPoint!);
                  Waypoint dragEnd = _draggedPoint!.clone();
                  UndoRedo.addChange(Change(
                    _dragOldValue,
                    () {
                      setState(() {
                        if (waypoints[index] != _draggedPoint) {
                          waypoints[index] = dragEnd.clone();
                        }
                        widget.path.generateAndSavePath();
                      });
                    },
                    (oldValue) {
                      setState(() {
                        waypoints[index] = oldValue.clone();
                        widget.path.generateAndSavePath();
                      });
                    },
                  ));
                  _draggedPoint = null;
                } else if (_draggedRotationIdx != null) {
                  if (_draggedRotationIdx == -1) {
                    num endRotation = widget.path.goalEndState.rotation;
                    UndoRedo.addChange(Change(
                      _dragRotationOldValue,
                      () {
                        setState(() {
                          widget.path.goalEndState.rotation = endRotation;
                          widget.path.generateAndSavePath();
                        });
                      },
                      (oldValue) {
                        setState(() {
                          widget.path.goalEndState.rotation = oldValue;
                          widget.path.generateAndSavePath();
                        });
                      },
                    ));
                  } else {
                    int rotationIdx = _draggedRotationIdx!;
                    num endRotation = widget
                        .path.rotationTargets[rotationIdx].rotationDegrees;
                    UndoRedo.addChange(Change(
                      _dragRotationOldValue,
                      () {
                        setState(() {
                          widget.path.rotationTargets[rotationIdx]
                              .rotationDegrees = endRotation;
                          widget.path.generateAndSavePath();
                        });
                      },
                      (oldValue) {
                        setState(() {
                          widget.path.rotationTargets[rotationIdx]
                              .rotationDegrees = oldValue;
                          widget.path.generateAndSavePath();
                        });
                      },
                    ));
                  }
                  _draggedRotationIdx = null;
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Stack(
                  children: [
                    widget.fieldImage.getWidget(),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PathPainter(
                          path: widget.path,
                          fieldImage: widget.fieldImage,
                          hoveredWaypoint: _hoveredWaypoint,
                          selectedWaypoint: _selectedWaypoint,
                          hoveredZone: _hoveredZone,
                          selectedZone: _selectedZone,
                          hoveredRotTarget: _hoveredRotTarget,
                          selectedRotTarget: _selectedRotTarget,
                          hoveredMarker: _hoveredMarker,
                          selectedMarker: _selectedMarker,
                          robotSize: _robotSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        MultiSplitViewTheme(
          data: MultiSplitViewThemeData(
            dividerPainter: DividerPainters.grooved1(
              color: colorScheme.surfaceVariant,
              highlightedColor: colorScheme.primary,
            ),
          ),
          child: MultiSplitView(
            axis: Axis.horizontal,
            controller: _controller,
            onWeightChange: () {
              double? newWeight = _treeOnRight
                  ? _controller.areas[1].weight
                  : _controller.areas[0].weight;
              widget.prefs
                  .setDouble(PrefsKeys.editorTreeWeight, newWeight ?? 0.5);
            },
            children: [
              if (_treeOnRight) Container(),
              Card(
                margin: const EdgeInsets.all(0),
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft:
                        _treeOnRight ? const Radius.circular(12) : Radius.zero,
                    topRight:
                        _treeOnRight ? Radius.zero : const Radius.circular(12),
                    bottomLeft:
                        _treeOnRight ? const Radius.circular(12) : Radius.zero,
                    bottomRight:
                        _treeOnRight ? Radius.zero : const Radius.circular(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: PathTree(
                    path: widget.path,
                    initiallySelectedWaypoint: _selectedWaypoint,
                    initiallySelectedZone: _selectedZone,
                    initiallySelectedRotTarget: _selectedRotTarget,
                    initiallySelectedMarker: _selectedMarker,
                    waypointsTreeController: _waypointsTreeController,
                    onPathChanged: () {
                      setState(() {
                        widget.path.generateAndSavePath();
                      });
                    },
                    onWaypointDeleted: (waypointIdx) {
                      UndoRedo.addChange(Change(
                        [
                          PathPlannerPath.cloneWaypoints(widget.path.waypoints),
                          PathPlannerPath.cloneConstraintZones(
                              widget.path.constraintZones),
                          PathPlannerPath.cloneEventMarkers(
                              widget.path.eventMarkers),
                          PathPlannerPath.cloneRotationTargets(
                              widget.path.rotationTargets),
                        ],
                        () {
                          setState(() {
                            _selectedWaypoint = null;
                            _hoveredWaypoint = null;
                            _waypointsTreeController.setSelectedWaypoint(null);

                            Waypoint w =
                                widget.path.waypoints.removeAt(waypointIdx);

                            if (w.isEndPoint()) {
                              waypoints[widget.path.waypoints.length - 1]
                                  .nextControl = null;
                            } else if (w.isStartPoint()) {
                              waypoints[0].prevControl = null;
                            }

                            for (ConstraintsZone zone
                                in widget.path.constraintZones) {
                              zone.minWaypointRelativePos =
                                  _adjustDeletedWaypointRelativePos(
                                      zone.minWaypointRelativePos, waypointIdx);
                              zone.maxWaypointRelativePos =
                                  _adjustDeletedWaypointRelativePos(
                                      zone.maxWaypointRelativePos, waypointIdx);
                            }

                            for (EventMarker m in widget.path.eventMarkers) {
                              m.waypointRelativePos =
                                  _adjustDeletedWaypointRelativePos(
                                      m.waypointRelativePos, waypointIdx);
                            }

                            for (RotationTarget t
                                in widget.path.rotationTargets) {
                              t.waypointRelativePos =
                                  _adjustDeletedWaypointRelativePos(
                                      t.waypointRelativePos, waypointIdx);
                            }

                            widget.path.generateAndSavePath();
                          });
                        },
                        (oldValue) {
                          setState(() {
                            _selectedWaypoint = null;
                            _hoveredWaypoint = null;
                            _waypointsTreeController.setSelectedWaypoint(null);

                            widget.path.waypoints =
                                PathPlannerPath.cloneWaypoints(oldValue[0]);
                            widget.path.constraintZones =
                                PathPlannerPath.cloneConstraintZones(
                                    oldValue[1]);
                            widget.path.eventMarkers =
                                PathPlannerPath.cloneEventMarkers(oldValue[2]);
                            widget.path.rotationTargets =
                                PathPlannerPath.cloneRotationTargets(
                                    oldValue[3]);
                            widget.path.generateAndSavePath();
                          });
                        },
                      ));
                    },
                    onSideSwapped: () => setState(() {
                      _treeOnRight = !_treeOnRight;
                      widget.prefs.setBool(PrefsKeys.treeOnRight, _treeOnRight);
                      _controller.areas = _controller.areas.reversed.toList();
                    }),
                    onWaypointHovered: (value) {
                      setState(() {
                        _hoveredWaypoint = value;
                      });
                    },
                    onWaypointSelected: (value) {
                      setState(() {
                        _selectedWaypoint = value;
                      });
                    },
                    onZoneHovered: (value) {
                      setState(() {
                        _hoveredZone = value;
                      });
                    },
                    onZoneSelected: (value) {
                      setState(() {
                        _selectedZone = value;
                      });
                    },
                    onRotTargetHovered: (value) {
                      setState(() {
                        _hoveredRotTarget = value;
                      });
                    },
                    onRotTargetSelected: (value) {
                      setState(() {
                        _selectedRotTarget = value;
                      });
                    },
                    onMarkerHovered: (value) {
                      setState(() {
                        _hoveredMarker = value;
                      });
                    },
                    onMarkerSelected: (value) {
                      setState(() {
                        _selectedMarker = value;
                      });
                    },
                  ),
                ),
              ),
              if (!_treeOnRight) Container(),
            ],
          ),
        ),
      ],
    );
  }

  num _adjustDeletedWaypointRelativePos(num pos, int deletedWaypointIdx) {
    if (pos >= deletedWaypointIdx + 1) {
      return pos - 1.0;
    } else if (pos >= deletedWaypointIdx) {
      int segment = pos.floor();
      double segmentPct = pos % 1.0;

      return max(
          (((segment - 0.5) + (segmentPct / 2.0)) * 20).round() / 20.0, 0.0);
    } else if (pos > deletedWaypointIdx - 1) {
      int segment = pos.floor();
      double segmentPct = pos % 1.0;

      return min(widget.path.waypoints.length - 1,
          ((segment + (0.5 * segmentPct)) * 20).round() / 20.0);
    }

    return pos;
  }

  void _setSelectedWaypoint(int? waypointIdx) {
    setState(() {
      _selectedWaypoint = waypointIdx;
    });

    _waypointsTreeController.setSelectedWaypoint(waypointIdx);
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels - 48) / _PathPainter.scale) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _yPixelsToMeters(double pixels) {
    return (widget.fieldImage.defaultSize.height -
            ((pixels - 48) / _PathPainter.scale)) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _pixelsToMeters(double pixels) {
    return (pixels / _PathPainter.scale) / widget.fieldImage.pixelsPerMeter;
  }
}

class _PathPainter extends CustomPainter {
  final PathPlannerPath path;
  final FieldImage fieldImage;
  final int? hoveredWaypoint;
  final int? selectedWaypoint;
  final int? hoveredZone;
  final int? selectedZone;
  final int? hoveredRotTarget;
  final int? selectedRotTarget;
  final int? hoveredMarker;
  final int? selectedMarker;
  final Size robotSize;

  late num robotRadius;

  static double scale = 1;

  _PathPainter({
    required this.path,
    required this.fieldImage,
    this.hoveredWaypoint,
    this.selectedWaypoint,
    this.hoveredZone,
    this.selectedZone,
    this.hoveredRotTarget,
    this.selectedRotTarget,
    this.hoveredMarker,
    this.selectedMarker,
    required this.robotSize,
  }) {
    robotRadius = sqrt((robotSize.width * robotSize.width) +
            (robotSize.height * robotSize.height)) /
        2.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    _paintRadius(canvas, scale);

    _paintPathPoints(path.pathPoints, canvas, scale, Colors.grey[300]!);

    _paintRotations(canvas, scale);

    _paintMarkers(canvas);

    for (int i = 0; i < path.waypoints.length; i++) {
      _paintWaypoint(canvas, scale, i);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  void _paintMarkers(Canvas canvas) {
    for (int i = 0; i < path.eventMarkers.length; i++) {
      int pointIdx = (path.eventMarkers[i].waypointRelativePos / 0.05).round();

      Color markerColor = Colors.grey[700]!;
      if (selectedMarker == i) {
        markerColor = Colors.orange;
      } else if (hoveredMarker == i) {
        markerColor = Colors.deepPurpleAccent;
      }

      Offset markerPos = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[pointIdx].position, scale, fieldImage);

      PathPainterUtil.paintMarker(canvas, markerPos, markerColor);
    }
  }

  void _paintRotations(Canvas canvas, double scale) {
    for (int i = 0; i < path.rotationTargets.length; i++) {
      int pointIdx =
          (path.rotationTargets[i].waypointRelativePos / 0.05).round();

      Color rotationColor = Colors.grey[700]!;
      if (selectedRotTarget == i) {
        rotationColor = Colors.orange;
      } else if (hoveredRotTarget == i) {
        rotationColor = Colors.deepPurpleAccent;
      }

      _paintRobotOutline(path.pathPoints[pointIdx].position,
          path.rotationTargets[i].rotationDegrees, canvas, rotationColor);
    }

    _paintRobotOutline(path.waypoints[path.waypoints.length - 1].anchor,
        path.goalEndState.rotation, canvas, Colors.red.withOpacity(0.5));
  }

  void _paintRobotOutline(
      Point position, num rotationDegrees, Canvas canvas, Color color) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    Offset center =
        PathPainterUtil.pointToPixelOffset(position, scale, fieldImage);
    num angle = -rotationDegrees / 180 * pi;
    double halfWidth =
        PathPainterUtil.metersToPixels(robotSize.width / 2, scale, fieldImage);
    double halfLength =
        PathPainterUtil.metersToPixels(robotSize.height / 2, scale, fieldImage);

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
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    paint.color = Colors.black;
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
  }

  void _paintRadius(Canvas canvas, double scale) {
    if (selectedWaypoint != null) {
      var paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.grey[800]!
        ..strokeWidth = 2;

      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              path.waypoints[selectedWaypoint!].anchor, scale, fieldImage),
          PathPainterUtil.metersToPixels(
              robotRadius.toDouble(), scale, fieldImage),
          paint);
    }
  }

  void _paintPathPoints(List<PathPoint> pathPoints, Canvas canvas, double scale,
      Color baseColor) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 2;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        pathPoints[0].position, scale, fieldImage);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < pathPoints.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          pathPoints[i].position, scale, fieldImage);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);

    if (selectedZone != null) {
      paint.color = Colors.orange;
      paint.strokeWidth = 4;
      p.reset();

      int startIdx =
          (path.constraintZones[selectedZone!].minWaypointRelativePos / 0.05)
              .round();
      int endIdx = min(
          (path.constraintZones[selectedZone!].maxWaypointRelativePos / 0.05)
              .round(),
          pathPoints.length - 1);
      Offset start = PathPainterUtil.pointToPixelOffset(
          pathPoints[startIdx].position, scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (int i = startIdx; i <= endIdx; i++) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            pathPoints[i].position, scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }

      canvas.drawPath(p, paint);
    }
    if (hoveredZone != null && selectedZone != hoveredZone) {
      paint.color = Colors.deepPurpleAccent;
      paint.strokeWidth = 4;
      p.reset();

      int startIdx =
          (path.constraintZones[hoveredZone!].minWaypointRelativePos / 0.05)
              .round();
      int endIdx = min(
          (path.constraintZones[hoveredZone!].maxWaypointRelativePos / 0.05)
              .round(),
          pathPoints.length - 1);
      Offset start = PathPainterUtil.pointToPixelOffset(
          pathPoints[startIdx].position, scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (int i = startIdx; i <= endIdx; i++) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            pathPoints[i].position, scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }

      canvas.drawPath(p, paint);
    }
  }

  void _paintWaypoint(Canvas canvas, double scale, int waypointIdx) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (waypointIdx == selectedWaypoint) {
      paint.color = Colors.orange;
    } else if (waypointIdx == hoveredWaypoint) {
      paint.color = Colors.deepPurpleAccent;
    } else {
      paint.color = Colors.grey[700]!;
    }

    Waypoint waypoint = path.waypoints[waypointIdx];

    //draw control point lines
    if (waypoint.nextControl != null) {
      canvas.drawLine(
          PathPainterUtil.pointToPixelOffset(
              waypoint.anchor, scale, fieldImage),
          PathPainterUtil.pointToPixelOffset(
              waypoint.nextControl!, scale, fieldImage),
          paint);
    }
    if (waypoint.prevControl != null) {
      canvas.drawLine(
          PathPainterUtil.pointToPixelOffset(
              waypoint.anchor, scale, fieldImage),
          PathPainterUtil.pointToPixelOffset(
              waypoint.prevControl!, scale, fieldImage),
          paint);
    }

    if (waypointIdx == 0) {
      paint.color = Colors.green;
    } else if (waypointIdx == path.waypoints.length - 1) {
      paint.color = Colors.red;
    } else {
      paint.color = Colors.grey[300]!;
    }

    if (waypointIdx == selectedWaypoint) {
      paint.color = Colors.orange;
    } else if (waypointIdx == hoveredWaypoint) {
      paint.color = Colors.deepPurpleAccent;
    }

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);

    // draw control points
    if (waypoint.nextControl != null) {
      paint.style = PaintingStyle.fill;
      if (waypointIdx == selectedWaypoint) {
        paint.color = Colors.orange;
      } else if (waypointIdx == hoveredWaypoint) {
        paint.color = Colors.deepPurpleAccent;
      } else {
        paint.color = Colors.grey[300]!;
      }

      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              waypoint.nextControl!, scale, fieldImage),
          PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
          paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              waypoint.nextControl!, scale, fieldImage),
          PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
          paint);
    }
    if (waypoint.prevControl != null) {
      paint.style = PaintingStyle.fill;
      if (waypointIdx == selectedWaypoint) {
        paint.color = Colors.orange;
      } else if (waypointIdx == hoveredWaypoint) {
        paint.color = Colors.deepPurpleAccent;
      } else {
        paint.color = Colors.grey[300]!;
      }

      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              waypoint.prevControl!, scale, fieldImage),
          PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
          paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              waypoint.prevControl!, scale, fieldImage),
          PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
          paint);
    }
  }
}