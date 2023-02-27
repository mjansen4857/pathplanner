import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/path_editor/cards/generator_settings_card.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:pathplanner/widgets/path_editor/cards/waypoint_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class EditEditor extends StatefulWidget {
  final RobotPath path;
  final Size robotSize;
  final bool holonomicMode;
  final bool focusedSelection;
  final FieldImage fieldImage;
  final void Function(RobotPath path) savePath;
  final bool showGeneratorSettings;
  final SharedPreferences prefs;

  const EditEditor(
      {required this.path,
      required this.robotSize,
      required this.holonomicMode,
      required this.fieldImage,
      required this.savePath,
      this.showGeneratorSettings = false,
      this.focusedSelection = false,
      required this.prefs,
      super.key});

  @override
  State<EditEditor> createState() => _EditEditorState();
}

class _EditEditorState extends State<EditEditor> {
  Waypoint? _draggedPoint;
  Waypoint? _selectedWaypoint;
  int _selectedPointIndex = -1;
  Waypoint? _dragOldValue;
  final GlobalKey _key = GlobalKey();

  List<Waypoint> get waypoints => widget.path.waypoints;

  @override
  void initState() {
    super.initState();
  }

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
        deselectWaypoint();
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
          deselectWaypoint();
          UndoRedo.redo();
        },
        child: KeyBoardShortcuts(
          keysToPress: Platform.isMacOS
              ? {LogicalKeyboardKey.meta, LogicalKeyboardKey.backspace}
              : {LogicalKeyboardKey.delete},
          onKeysPressed: () {
            if (_selectedWaypoint != null) {
              removeWaypoint(_selectedWaypoint!);
            }
          },
          child: Stack(
            key: _key,
            children: [
              _buildEditor(),
              _buildWaypointCard(),
              _buildGeneratorSettingsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    int waypointsMinIndex = 0;
    int waypointsMaxIndex = waypoints.length;

    if (widget.focusedSelection && _selectedWaypoint != null) {
      waypointsMinIndex = max(0, _selectedPointIndex - 1);
      waypointsMaxIndex = min(_selectedPointIndex + 2, waypointsMaxIndex);
    }

    return Center(
      child: InteractiveViewer(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) {
            UndoRedo.addChange(Change(
              [
                RobotPath.cloneWaypointList(waypoints),
                _selectedPointIndex == -1 ||
                        _selectedPointIndex >= waypoints.length
                    ? waypoints.length - 1
                    : _selectedPointIndex
              ],
              () {
                setState(() {
                  widget.path.addWaypoint(
                      Point(_xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy)),
                      _selectedPointIndex == -1 ||
                              _selectedPointIndex >= waypoints.length
                          ? waypoints.length - 1
                          : _selectedPointIndex);
                  widget.savePath(widget.path);
                });
              },
              (oldValue) {
                setState(() {
                  if (oldValue[1] == oldValue[0].length - 1) {
                    waypoints.removeLast();
                    waypoints.last.nextControl = null;
                  } else {
                    waypoints.removeAt(oldValue[1] + 1);
                    waypoints[oldValue[1]].nextControl =
                        oldValue[0][oldValue[1]].nextControl;
                    waypoints[oldValue[1] + 1].prevControl =
                        oldValue[0][oldValue[1] + 1].prevControl;
                  }
                  _selectedPointIndex = -1;
                  widget.savePath(widget.path);
                });
              },
            ));
            setState(() {
              for (var i = waypointsMinIndex; i < waypointsMaxIndex; i++) {
                Waypoint w = waypoints[i];
                if (w.isPointInAnchor(
                        _xPixelsToMeters(details.localPosition.dx),
                        _yPixelsToMeters(details.localPosition.dy),
                        _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                            25, _EditPainter.scale, widget.fieldImage))) ||
                    w.isPointInNextControl(
                        _xPixelsToMeters(details.localPosition.dx),
                        _yPixelsToMeters(details.localPosition.dy),
                        _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                            20, _EditPainter.scale, widget.fieldImage))) ||
                    w.isPointInPrevControl(
                        _xPixelsToMeters(details.localPosition.dx),
                        _yPixelsToMeters(details.localPosition.dy),
                        _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                            20, _EditPainter.scale, widget.fieldImage))) ||
                    w.isPointInHolonomicThing(
                        _xPixelsToMeters(details.localPosition.dx),
                        _yPixelsToMeters(details.localPosition.dy),
                        _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                            15, _EditPainter.scale, widget.fieldImage)),
                        widget.robotSize.height)) {
                  setSelectedWaypointIndex(i);
                }
              }
            });
          },
          onDoubleTap: () {},
          onTapDown: (details) {
            FocusScopeNode currentScope = FocusScope.of(context);
            if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
              FocusManager.instance.primaryFocus!.unfocus();
            }
            for (var i = waypointsMinIndex; i < waypointsMaxIndex; i++) {
              Waypoint w = waypoints[i];
              if (w.isPointInAnchor(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                          25, _EditPainter.scale, widget.fieldImage))) ||
                  w.isPointInNextControl(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                          20, _EditPainter.scale, widget.fieldImage))) ||
                  w.isPointInPrevControl(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                          20, _EditPainter.scale, widget.fieldImage))) ||
                  w.isPointInHolonomicThing(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                          15, _EditPainter.scale, widget.fieldImage)),
                      widget.robotSize.height)) {
                setSelectedWaypointIndex(i);
                return;
              }
            }
            deselectWaypoint();
          },
          onPanStart: (details) {
            for (int i = waypointsMaxIndex - 1; i >= waypointsMinIndex; i--) {
              Waypoint w = waypoints[i];
              if (w.startDragging(
                  _xPixelsToMeters(details.localPosition.dx),
                  _yPixelsToMeters(details.localPosition.dy),
                  _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                      25, _EditPainter.scale, widget.fieldImage)),
                  _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                      20, _EditPainter.scale, widget.fieldImage)),
                  _pixelsToMeters(PathPainterUtil.uiPointSizeToPixels(
                      15, _EditPainter.scale, widget.fieldImage)),
                  widget.robotSize.height,
                  widget.holonomicMode)) {
                _draggedPoint = w;
                _dragOldValue = w.clone();
                break;
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
                                _EditPainter.scale),
                        max(8, details.localPosition.dx))),
                    _yPixelsToMeters(min(
                        88 +
                            (widget.fieldImage.defaultSize.height *
                                _EditPainter.scale),
                        max(8, details.localPosition.dy))));
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
                    widget.savePath(widget.path);
                  });
                },
                (oldValue) {
                  setState(() {
                    waypoints[index] = oldValue.clone();
                    widget.savePath(widget.path);
                  });
                },
              ));
              _draggedPoint = null;
            }
          },
          child: Container(
            padding: const EdgeInsets.all(48),
            child: Stack(
              children: [
                widget.fieldImage.getWidget(),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EditPainter(
                        widget.path,
                        widget.fieldImage,
                        widget.robotSize,
                        widget.holonomicMode,
                        _selectedWaypoint,
                        widget.focusedSelection),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaypointCard() {
    String? waypointLabel = widget.path.getWaypointLabel(_selectedWaypoint);
    if (waypointLabel == null) {
      // Somehow the selected waypoint is not in the path. Reset selected point.
      deselectWaypoint();
    }

    return WaypointCard(
      waypoint: _selectedWaypoint,
      stackKey: _key,
      label: waypointLabel,
      holonomicEnabled: widget.holonomicMode,
      deleteEnabled: waypoints.length > 2,
      prefs: widget.prefs,
      onDelete: () => removeWaypoint(_selectedWaypoint!),
      onShouldSave: () {
        widget.savePath(widget.path);
      },
      onNextWaypoint:
          _selectedPointIndex < waypoints.length - 1 ? nextWaypoint : null,
      onPrevWaypoint: _selectedPointIndex > 0 ? previousWaypoint : null,
    );
  }

  void previousWaypoint() {
    setSelectedWaypointIndex(_selectedPointIndex - 1);
  }

  void nextWaypoint() {
    setSelectedWaypointIndex(_selectedPointIndex + 1);
  }

  void setSelectedWaypointIndex(int index) {
    if (waypoints.isEmpty) {
      return deselectWaypoint();
    }

    setState(() {
      _selectedPointIndex = index.clamp(0, waypoints.length - 1);
      _selectedWaypoint = waypoints[_selectedPointIndex];
    });
  }

  void deselectWaypoint() {
    setState(() {
      _selectedPointIndex = -1;
      _selectedWaypoint = null;
    });
  }

  void removeWaypoint(Waypoint waypoint) {
    int delIndex = waypoints.indexOf(waypoint);
    UndoRedo.addChange(Change(
      RobotPath.cloneWaypointList(waypoints),
      () {
        setState(() {
          Waypoint w = waypoints.removeAt(delIndex);
          if (w.isEndPoint()) {
            waypoints[waypoints.length - 1].nextControl = null;
            waypoints[waypoints.length - 1].isReversal = false;
            waypoints[waypoints.length - 1].isStopPoint = false;
            waypoints[waypoints.length - 1].holonomicAngle ??= 0;
          } else if (w.isStartPoint()) {
            waypoints[0].prevControl = null;
            waypoints[0].isReversal = false;
            waypoints[0].isStopPoint = false;
            waypoints[0].holonomicAngle ??= 0;
          }

          widget.savePath(widget.path);
        });
      },
      (oldValue) {
        setState(() {
          widget.path.waypoints = RobotPath.cloneWaypointList(oldValue);
          widget.savePath(widget.path);
        });
      },
    ));
    deselectWaypoint();
  }

  Widget _buildGeneratorSettingsCard() {
    return Visibility(
      visible: widget.showGeneratorSettings,
      child: GeneratorSettingsCard(
        path: widget.path,
        holonomicMode: widget.holonomicMode,
        stackKey: _key,
        onShouldSave: () {
          widget.savePath(widget.path);
        },
        prefs: widget.prefs,
      ),
    );
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels - 48) / _EditPainter.scale) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _yPixelsToMeters(double pixels) {
    return (widget.fieldImage.defaultSize.height -
            ((pixels - 48) / _EditPainter.scale)) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _pixelsToMeters(double pixels) {
    return (pixels / _EditPainter.scale) / widget.fieldImage.pixelsPerMeter;
  }
}

class _EditPainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final bool focusedSelection;
  final Waypoint? selectedWaypoint;

  static double scale = 1;

  _EditPainter(this.path, this.fieldImage, this.robotSize, this.holonomicMode,
      this.selectedWaypoint, this.focusedSelection);

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    if (holonomicMode) {
      PathPainterUtil.paintCenterPath(
          path, canvas, scale, Colors.grey[300]!, fieldImage,
          selectedWaypoint: selectedWaypoint,
          focusedSelection: focusedSelection);
    } else {
      PathPainterUtil.paintDualPaths(
          path, robotSize, canvas, scale, Colors.grey[300]!, fieldImage,
          selectedWaypoint: selectedWaypoint,
          focusedSelection: focusedSelection);
    }

    int waypointsMinIndex = 0;
    int waypointsMaxIndex = path.waypoints.length;

    if (focusedSelection && selectedWaypoint != null) {
      int selectedIndex = path.waypoints.indexOf(selectedWaypoint!);
      waypointsMinIndex = max(0, selectedIndex - 1);
      waypointsMaxIndex = min(selectedIndex + 2, waypointsMaxIndex);
    }

    for (Waypoint w
        in path.waypoints.sublist(waypointsMinIndex, waypointsMaxIndex)) {
      Color color = Colors.grey[300]!;

      if (w.isStopPoint) {
        color = Colors.deepPurpleAccent;
      }

      if (w == selectedWaypoint) {
        color = Colors.orange;
      }

      PathPainterUtil.paintRobotOutline(
          w, robotSize, holonomicMode, canvas, scale, color, fieldImage);
      _paintEditableWaypoint(canvas, scale, w);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void _paintEditableWaypoint(Canvas canvas, double scale, Waypoint waypoint) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 2;

    //draw control point lines
    if (waypoint.nextControl != null) {
      canvas.drawLine(
          PathPainterUtil.pointToPixelOffset(
              waypoint.anchorPoint, scale, fieldImage),
          PathPainterUtil.pointToPixelOffset(
              waypoint.nextControl!, scale, fieldImage),
          paint);
    }
    if (waypoint.prevControl != null) {
      canvas.drawLine(
          PathPainterUtil.pointToPixelOffset(
              waypoint.anchorPoint, scale, fieldImage),
          PathPainterUtil.pointToPixelOffset(
              waypoint.prevControl!, scale, fieldImage),
          paint);
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
        PathPainterUtil.pointToPixelOffset(
            waypoint.anchorPoint, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(
            waypoint.anchorPoint, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);

    // draw control points
    if (waypoint.nextControl != null) {
      paint.style = PaintingStyle.fill;
      paint.color = Colors.grey[300]!;

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
      paint.color = Colors.grey[300]!;

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
