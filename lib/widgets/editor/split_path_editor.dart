import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/point_towards_zone.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/dialogs/trajectory_render_dialog.dart';
import 'package:pathplanner/widgets/editor/path_painter.dart';
import 'package:pathplanner/widgets/editor/preview_seekbar.dart';
import 'package:pathplanner/widgets/editor/runtime_display.dart';
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
  final bool hotReload;
  final bool simulate;
  final VoidCallback? onPathChanged;

  const SplitPathEditor({
    required this.prefs,
    required this.path,
    required this.fieldImage,
    required this.undoStack,
    this.telemetry,
    this.hotReload = false,
    this.simulate = false,
    this.onPathChanged,
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
  int? _hoveredPointZone;
  int? _selectedPointZone;
  int? _hoveredMarker;
  int? _selectedMarker;
  late bool _treeOnRight;
  Waypoint? _draggedPoint;
  Waypoint? _dragOldValue;
  int? _draggedRotationIdx;
  Translation2d? _draggedRotationPos;
  Rotation2d? _dragRotationOldValue;
  PathPlannerTrajectory? _simTraj;
  bool _paused = false;
  late bool _holonomicMode;

  PathPlannerPath? _optimizedPath;

  late Size _robotSize;
  late AnimationController _previewController;

  List<Waypoint> get waypoints => widget.path.waypoints;

  RuntimeDisplay? _runtimeDisplay;

  @override
  void initState() {
    super.initState();

    _previewController = AnimationController(vsync: this);

    _holonomicMode =
        widget.prefs.getBool(PrefsKeys.holonomicMode) ?? Defaults.holonomicMode;

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
        minimalWeight: 0.4,
      ),
      Area(
        weight: _treeOnRight ? treeWeight : (1.0 - treeWeight),
        minimalWeight: 0.4,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) => _simulatePath());
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
                      widget.path.addWaypoint(Translation2d(
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
                for (int i = 0; i < widget.path.pathPoints.length; i++) {
                  Rotation2d rotation;
                  Translation2d pos;
                  if (i == 0) {
                    rotation = widget.path.idealStartingState.rotation;
                    pos = widget.path.pathPoints.first.position;
                  } else if (i == widget.path.pathPoints.length - 1) {
                    rotation = widget.path.goalEndState.rotation;
                    pos = widget.path.pathPoints.last.position;
                  } else if (widget.path.pathPoints[i].rotationTarget != null) {
                    rotation =
                        widget.path.pathPoints[i].rotationTarget!.rotation;
                    pos = widget.path.pathPoints[i].position;
                  } else {
                    continue;
                  }

                  num dotX = pos.x + (_robotSize.height / 2 * rotation.cosine);
                  num dotY = pos.y + (_robotSize.height / 2 * rotation.sine);
                  if (pow(xPos - dotX, 2) + pow(yPos - dotY, 2) <
                      pow(dotRadius, 2)) {
                    if (i == 0) {
                      _draggedRotationIdx = -2;
                    } else if (i == widget.path.pathPoints.length - 2) {
                      _draggedRotationIdx = -1;
                    } else {
                      _draggedRotationIdx = widget.path.rotationTargets
                          .indexOf(widget.path.pathPoints[i].rotationTarget!);
                    }
                    _draggedRotationPos = pos;
                    _dragRotationOldValue = rotation;
                    return;
                  }
                }
              },
              onPanUpdate: (details) {
                if (_draggedPoint != null) {
                  num targetX = _xPixelsToMeters(min(
                      88 +
                          (widget.fieldImage.defaultSize.width *
                              PathPainter.scale),
                      max(8, details.localPosition.dx)));
                  num targetY = _yPixelsToMeters(min(
                      88 +
                          (widget.fieldImage.defaultSize.height *
                              PathPainter.scale),
                      max(8, details.localPosition.dy)));

                  bool snapSetting =
                      widget.prefs.getBool(PrefsKeys.snapToGuidelines) ??
                          Defaults.snapToGuidelines;
                  bool ctrlHeld = HardwareKeyboard.instance.logicalKeysPressed
                          .contains(LogicalKeyboardKey.controlLeft) ||
                      HardwareKeyboard.instance.logicalKeysPressed
                          .contains(LogicalKeyboardKey.controlRight);

                  bool shouldSnap = snapSetting ^ ctrlHeld;

                  if (shouldSnap && _draggedPoint!.isAnchorDragging) {
                    num? closestX;
                    num? closestY;

                    for (Waypoint w in waypoints) {
                      if (w != _draggedPoint) {
                        if (closestX == null ||
                            (targetX - w.anchor.x).abs() <
                                (targetX - closestX).abs()) {
                          closestX = w.anchor.x;
                        }

                        if (closestY == null ||
                            (targetY - w.anchor.y).abs() <
                                (targetY - closestY).abs()) {
                          closestY = w.anchor.y;
                        }
                      }
                    }

                    if (closestX != null && (targetX - closestX).abs() < 0.1) {
                      targetX = closestX;
                    }
                    if (closestY != null && (targetY - closestY).abs() < 0.1) {
                      targetY = closestY;
                    }
                  }

                  setState(() {
                    _draggedPoint!.dragUpdate(targetX, targetY);
                    widget.path.generatePathPoints();
                  });
                } else if (_draggedRotationIdx != null) {
                  Translation2d pos;
                  if (_draggedRotationIdx == -2) {
                    pos = widget.path.waypoints.first.anchor;
                  } else if (_draggedRotationIdx == -1) {
                    pos = widget.path.waypoints.last.anchor;
                  } else {
                    pos = _draggedRotationPos!;
                  }

                  double x = _xPixelsToMeters(details.localPosition.dx);
                  double y = _yPixelsToMeters(details.localPosition.dy);

                  setState(() {
                    if (_draggedRotationIdx == -2) {
                      widget.path.idealStartingState.rotation =
                          Rotation2d.fromComponents(x - pos.x, y - pos.y);
                    } else if (_draggedRotationIdx == -1) {
                      widget.path.goalEndState.rotation =
                          Rotation2d.fromComponents(x - pos.x, y - pos.y);
                    } else {
                      widget.path.rotationTargets[_draggedRotationIdx!]
                              .rotation =
                          Rotation2d.fromComponents(x - pos.x, y - pos.y);
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
                        widget.onPathChanged?.call();
                      });
                      if (widget.hotReload) {
                        widget.telemetry?.hotReloadPath(widget.path);
                      }
                    },
                    (oldValue) {
                      setState(() {
                        waypoints[index] = oldValue!.clone();
                        widget.path.generateAndSavePath();
                        _simulatePath();
                        widget.onPathChanged?.call();
                      });
                      if (widget.hotReload) {
                        widget.telemetry?.hotReloadPath(widget.path);
                      }
                    },
                  ));
                  _draggedPoint = null;
                } else if (_draggedRotationIdx != null) {
                  if (_draggedRotationIdx == -2) {
                    final endRotation = widget.path.idealStartingState.rotation;
                    widget.undoStack.add(Change(
                      _dragRotationOldValue,
                      () {
                        setState(() {
                          widget.path.idealStartingState.rotation = endRotation;
                          widget.path.generateAndSavePath();
                          _simulatePath();
                        });
                      },
                      (oldValue) {
                        setState(() {
                          widget.path.idealStartingState.rotation = oldValue!;
                          widget.path.generateAndSavePath();
                          _simulatePath();
                        });
                      },
                    ));
                  } else if (_draggedRotationIdx == -1) {
                    final endRotation = widget.path.goalEndState.rotation;
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
                    final endRotation =
                        widget.path.rotationTargets[rotationIdx].rotation;
                    widget.undoStack.add(Change(
                      _dragRotationOldValue,
                      () {
                        setState(() {
                          widget.path.rotationTargets[rotationIdx].rotation =
                              endRotation;
                          widget.path.generateAndSavePath();
                          _simulatePath();
                        });
                      },
                      (oldValue) {
                        setState(() {
                          widget.path.rotationTargets[rotationIdx].rotation =
                              oldValue!;
                          widget.path.generateAndSavePath();
                          _simulatePath();
                        });
                      },
                    ));
                  }
                  _draggedRotationIdx = null;
                  _draggedRotationPos = null;
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
                          colorScheme: colorScheme,
                          paths: [widget.path],
                          simple: false,
                          fieldImage: widget.fieldImage,
                          hoveredWaypoint: _hoveredWaypoint,
                          selectedWaypoint: _selectedWaypoint,
                          hoveredZone: _hoveredZone,
                          selectedZone: _selectedZone,
                          hoveredPointZone: _hoveredPointZone,
                          selectedPointZone: _selectedPointZone,
                          hoveredRotTarget: _hoveredRotTarget,
                          selectedRotTarget: _selectedRotTarget,
                          hoveredMarker: _hoveredMarker,
                          selectedMarker: _selectedMarker,
                          simulatedPath: _simTraj,
                          animation: _previewController.view,
                          prefs: widget.prefs,
                          optimizedPath: _optimizedPath,
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
              color: colorScheme.surfaceContainerHighest,
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
              if (_treeOnRight)
                PreviewSeekbar(
                  previewController: _previewController,
                  onPauseStateChanged: (value) => _paused = value,
                  totalPathTime: _simTraj?.states.last.timeSeconds ?? 1.0,
                ),
              Card(
                margin: const EdgeInsets.all(0),
                elevation: 4.0,
                color: colorScheme.surface,
                surfaceTintColor: colorScheme.surfaceTint,
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
                    pathRuntime: _simTraj?.getTotalTimeSeconds(),
                    runtimeDisplay: _runtimeDisplay,
                    initiallySelectedWaypoint: _selectedWaypoint,
                    initiallySelectedZone: _selectedZone,
                    initiallySelectedRotTarget: _selectedRotTarget,
                    initiallySelectedPointZone: _selectedPointZone,
                    initiallySelectedMarker: _selectedMarker,
                    waypointsTreeController: _waypointsTreeController,
                    undoStack: widget.undoStack,
                    holonomicMode: _holonomicMode,
                    defaultConstraints: _getDefaultConstraints(),
                    prefs: widget.prefs,
                    fieldSizeMeters: widget.fieldImage.getFieldSizeMeters(),
                    onRenderPath: () {
                      if (_simTraj != null) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return TrajectoryRenderDialog(
                                fieldImage: widget.fieldImage,
                                prefs: widget.prefs,
                                trajectory: _simTraj!,
                              );
                            });
                      }
                    },
                    onPathChanged: () {
                      setState(() {
                        widget.path.generateAndSavePath();
                        _simulatePath();
                      });

                      if (widget.hotReload) {
                        widget.telemetry?.hotReloadPath(widget.path);
                      }

                      widget.onPathChanged?.call();
                    },
                    onPathChangedNoSim: () {
                      setState(() {
                        widget.path.generateAndSavePath();
                      });

                      if (widget.hotReload) {
                        widget.telemetry?.hotReloadPath(widget.path);
                      }

                      widget.onPathChanged?.call();
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
                          PathPlannerPath.clonePointTowardsZones(
                              widget.path.pointTowardsZones),
                        ],
                        () {
                          setState(() {
                            _selectedWaypoint = null;
                            _hoveredWaypoint = null;
                            _waypointsTreeController.setSelectedWaypoint(null);

                            Waypoint w =
                                widget.path.waypoints.removeAt(waypointIdx);

                            if (w.isEndPoint) {
                              waypoints[widget.path.waypoints.length - 1]
                                  .nextControl = null;
                            } else if (w.isStartPoint) {
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

                            for (PointTowardsZone zone
                                in widget.path.pointTowardsZones) {
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
                            widget.path.pointTowardsZones =
                                PathPlannerPath.clonePointTowardsZones(
                                    oldValue[4] as List<PointTowardsZone>);
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
                    onPointZoneHovered: (value) {
                      setState(() {
                        _hoveredPointZone = value;
                      });
                    },
                    onPointZoneSelected: (value) {
                      setState(() {
                        _selectedPointZone = value;
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
                    onOptimizationUpdate: (result) => setState(() {
                      _optimizedPath = result;
                    }),
                  ),
                ),
              ),
              if (!_treeOnRight)
                PreviewSeekbar(
                  previewController: _previewController,
                  onPauseStateChanged: (value) => _paused = value,
                  totalPathTime: _simTraj?.states.last.timeSeconds ?? 1.0,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // marked as async so it can be called from initState
  void _simulatePath() async {
    if (widget.simulate) {
      setState(() {
        _simTraj = PathPlannerTrajectory(
          path: widget.path,
          robotConfig: RobotConfig.fromPrefs(widget.prefs),
        );
        if (!(_simTraj?.getTotalTimeSeconds().isFinite ?? false)) {
          _simTraj = null;
        }

        // Update the RuntimeDisplay widget
        _runtimeDisplay = RuntimeDisplay(
          currentRuntime: _simTraj?.states.last.timeSeconds,
          previousRuntime: _runtimeDisplay?.currentRuntime,
        );
      });

      if (!_paused) {
        _previewController.stop();
        _previewController.reset();
      }

      if (_simTraj != null) {
        if (!_paused) {
          _previewController.duration = Duration(
              milliseconds: (_simTraj!.states.last.timeSeconds * 1000).toInt());
          _previewController.repeat();
        } else if (_previewController.duration != null) {
          double prevTime = _previewController.value *
              (_previewController.duration!.inMilliseconds / 1000.0);
          _previewController.duration = Duration(
              milliseconds: (_simTraj!.states.last.timeSeconds * 1000).toInt());
          double newPos = prevTime / _simTraj!.states.last.timeSeconds;
          _previewController.forward(from: newPos);
          _previewController.stop();
        }
      } else {
        // Trajectory failed to generate. Notify the user
        Log.warning(
            'Failed to generate trajectory for path: ${widget.path.name}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate trajectory. Please open an issue on the pathplanner github and include this path file',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Theme.of(context).colorScheme.onErrorContainer,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
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

  PathConstraints _getDefaultConstraints() {
    return PathConstraints(
      maxVelocityMPS: widget.prefs.getDouble(PrefsKeys.defaultMaxVel) ??
          Defaults.defaultMaxVel,
      maxAccelerationMPSSq: widget.prefs.getDouble(PrefsKeys.defaultMaxAccel) ??
          Defaults.defaultMaxAccel,
      maxAngularVelocityDeg:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAngVel) ??
              Defaults.defaultMaxAngVel,
      maxAngularAccelerationDeg:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAngAccel) ??
              Defaults.defaultMaxAngAccel,
    );
  }
}
