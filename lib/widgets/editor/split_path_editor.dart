import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/services/simulator/path_simulator.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/path_painter.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/waypoints_tree.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class SplitPathEditor extends StatefulWidget {
  final SharedPreferences prefs;
  final PathPlannerPath path;
  final FieldImage fieldImage;
  final ChangeStack undoStack;
  final PPLibTelemetry? telemetry;

  const SplitPathEditor({
    required this.prefs,
    required this.path,
    required this.fieldImage,
    required this.undoStack,
    this.telemetry,
    super.key,
  });

  @override
  State<SplitPathEditor> createState() => _SplitPathEditorState();
}

class _SplitPathEditorState extends State<SplitPathEditor>
    with SingleTickerProviderStateMixin {
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
  SimulatedPath? _simPath;

  late Size _robotSize;
  late AnimationController _previewController;

  List<Waypoint> get waypoints => widget.path.waypoints;

  @override
  void initState() {
    super.initState();

    _previewController = AnimationController(vsync: this);

    _treeOnRight =
        widget.prefs.getBool(PrefsKeys.treeOnRight) ?? Defaults.treeOnRight;

    var width =
        widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth;
    var length =
        widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength;
    _robotSize = Size(width, length);

    double treeWeight = widget.prefs.getDouble(PrefsKeys.editorTreeWeight) ??
        Defaults.editorTreeWeight;
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

    _simulatePath();
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
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
                              25, PathPainter.scale, widget.fieldImage))) ||
                      w.isPointInNextControl(
                          _xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy),
                          _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                              20, PathPainter.scale, widget.fieldImage))) ||
                      w.isPointInPrevControl(
                          _xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy),
                          _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                              20, PathPainter.scale, widget.fieldImage)))) {
                    _setSelectedWaypoint(i);
                    return;
                  }
                }
                _setSelectedWaypoint(null);
              },
              onDoubleTapDown: (details) {
                widget.undoStack.add(Change(
                  PathPlannerPath.cloneWaypoints(waypoints),
                  () {
                    setState(() {
                      widget.path.addWaypoint(Point(
                          _xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy)));
                      widget.path.generateAndSavePath();
                    });
                    _simulatePath();
                  },
                  (oldValue) {
                    setState(() {
                      widget.path.waypoints =
                          PathPlannerPath.cloneWaypoints(oldValue);
                      _setSelectedWaypoint(null);
                      widget.path.generateAndSavePath();
                      _simulatePath();
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
                          25, PathPainter.scale, widget.fieldImage)),
                      _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                          20, PathPainter.scale, widget.fieldImage)))) {
                    _draggedPoint = w;
                    _dragOldValue = w.clone();
                    break;
                  }
                }

                // Not dragging any waypoints, check rotations
                num dotRadius = _pixelsToMeters(
                    PathPainterUtil.uiPointSizeToPixels(
                        15, PathPainter.scale, widget.fieldImage));
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
                                    PathPainter.scale),
                            max(8, details.localPosition.dx))),
                        _yPixelsToMeters(min(
                            88 +
                                (widget.fieldImage.defaultSize.height *
                                    PathPainter.scale),
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
                  widget.undoStack.add(Change(
                    _dragOldValue,
                    () {
                      setState(() {
                        if (waypoints[index] != _draggedPoint) {
                          waypoints[index] = dragEnd.clone();
                        }
                        widget.path.generateAndSavePath();
                        _simulatePath();
                      });
                      // TODO: hot reload setting
                      widget.telemetry?.hotReloadPath(widget.path);
                    },
                    (oldValue) {
                      setState(() {
                        waypoints[index] = oldValue!.clone();
                        widget.path.generateAndSavePath();
                        _simulatePath();
                      });
                      // TODO: hot reload setting
                      widget.telemetry?.hotReloadPath(widget.path);
                    },
                  ));
                  _draggedPoint = null;
                } else if (_draggedRotationIdx != null) {
                  if (_draggedRotationIdx == -1) {
                    num endRotation = widget.path.goalEndState.rotation;
                    widget.undoStack.add(Change(
                      _dragRotationOldValue,
                      () {
                        setState(() {
                          widget.path.goalEndState.rotation = endRotation;
                          widget.path.generateAndSavePath();
                          _simulatePath();
                        });
                      },
                      (oldValue) {
                        setState(() {
                          widget.path.goalEndState.rotation = oldValue!;
                          widget.path.generateAndSavePath();
                          _simulatePath();
                        });
                      },
                    ));
                  } else {
                    int rotationIdx = _draggedRotationIdx!;
                    num endRotation = widget
                        .path.rotationTargets[rotationIdx].rotationDegrees;
                    widget.undoStack.add(Change(
                      _dragRotationOldValue,
                      () {
                        setState(() {
                          widget.path.rotationTargets[rotationIdx]
                              .rotationDegrees = endRotation;
                          widget.path.generateAndSavePath();
                          _simulatePath();
                        });
                      },
                      (oldValue) {
                        setState(() {
                          widget.path.rotationTargets[rotationIdx]
                              .rotationDegrees = oldValue!;
                          widget.path.generateAndSavePath();
                          _simulatePath();
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
                        painter: PathPainter(
                          paths: [widget.path],
                          simple: false,
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
                          simulatedPath: _simPath,
                          animation: _previewController.view,
                          previewColor: colorScheme.primary,
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
                    pathRuntime: _simPath?.runtime,
                    initiallySelectedWaypoint: _selectedWaypoint,
                    initiallySelectedZone: _selectedZone,
                    initiallySelectedRotTarget: _selectedRotTarget,
                    initiallySelectedMarker: _selectedMarker,
                    waypointsTreeController: _waypointsTreeController,
                    undoStack: widget.undoStack,
                    onPathChanged: () {
                      setState(() {
                        widget.path.generateAndSavePath();
                        _simulatePath();
                      });

                      // TODO: hot reload setting
                      widget.telemetry?.hotReloadPath(widget.path);
                    },
                    onPathChangedNoSim: () {
                      setState(() {
                        widget.path.generateAndSavePath();
                      });

                      // TODO: hot reload setting
                      widget.telemetry?.hotReloadPath(widget.path);
                    },
                    onWaypointDeleted: (waypointIdx) {
                      widget.undoStack.add(Change(
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
                            _simulatePath();
                          });
                        },
                        (oldValue) {
                          setState(() {
                            _selectedWaypoint = null;
                            _hoveredWaypoint = null;
                            _waypointsTreeController.setSelectedWaypoint(null);

                            widget.path.waypoints =
                                PathPlannerPath.cloneWaypoints(
                                    oldValue[0] as List<Waypoint>);
                            widget.path.constraintZones =
                                PathPlannerPath.cloneConstraintZones(
                                    oldValue[1] as List<ConstraintsZone>);
                            widget.path.eventMarkers =
                                PathPlannerPath.cloneEventMarkers(
                                    oldValue[2] as List<EventMarker>);
                            widget.path.rotationTargets =
                                PathPlannerPath.cloneRotationTargets(
                                    oldValue[3] as List<RotationTarget>);
                            widget.path.generateAndSavePath();
                            _simulatePath();
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

  void _simulatePath() async {
    Stopwatch s = Stopwatch()..start();
    SimulatedPath p = await compute(simulatePath, widget.path);
    Log.debug('Simulated path in ${s.elapsedMilliseconds}ms');
    setState(() {
      _simPath = p;
    });
    _previewController.stop();
    _previewController.reset();
    _previewController.duration =
        Duration(milliseconds: (p.runtime * 1000).toInt());
    _previewController.repeat();
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
    return ((pixels - 48) / PathPainter.scale) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _yPixelsToMeters(double pixels) {
    return (widget.fieldImage.defaultSize.height -
            ((pixels - 48) / PathPainter.scale)) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _pixelsToMeters(double pixels) {
    return (pixels / PathPainter.scale) / widget.fieldImage.pixelsPerMeter;
  }
}
