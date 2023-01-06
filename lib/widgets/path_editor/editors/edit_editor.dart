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
        setState(() {
          _selectedWaypoint = null;
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
            _selectedWaypoint = null;
          });
          UndoRedo.redo();
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
    );
  }

  Widget _buildEditor() {
    return Center(
      child: InteractiveViewer(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) {
            UndoRedo.addChange(Change(
              [
                RobotPath.cloneWaypointList(widget.path.waypoints),
                _selectedPointIndex == -1 ||
                        _selectedPointIndex >= widget.path.waypoints.length
                    ? widget.path.waypoints.length - 1
                    : _selectedPointIndex
              ],
              () {
                setState(() {
                  widget.path.addWaypoint(
                      Point(_xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy)),
                      _selectedPointIndex == -1 ||
                              _selectedPointIndex >=
                                  widget.path.waypoints.length
                          ? widget.path.waypoints.length - 1
                          : _selectedPointIndex);
                  widget.savePath(widget.path);
                });
              },
              (oldValue) {
                setState(() {
                  if (oldValue[1] == oldValue[0].length - 1) {
                    widget.path.waypoints.removeLast();
                    widget.path.waypoints.last.nextControl = null;
                  } else {
                    widget.path.waypoints.removeAt(oldValue[1] + 1);
                    widget.path.waypoints[oldValue[1]].nextControl =
                        oldValue[0][oldValue[1]].nextControl;
                    widget.path.waypoints[oldValue[1] + 1].prevControl =
                        oldValue[0][oldValue[1] + 1].prevControl;
                  }
                  _selectedPointIndex = -1;
                  widget.savePath(widget.path);
                });
              },
            ));
            setState(() {
              for (var i = 0; i < widget.path.waypoints.length; i++) {
                Waypoint w = widget.path.waypoints[i];
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
                  setState(() {
                    _selectedWaypoint = w;
                    _selectedPointIndex = i;
                  });
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
            for (var i = 0; i < widget.path.waypoints.length; i++) {
              Waypoint w = widget.path.waypoints[i];
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
                setState(() {
                  _selectedWaypoint = w;
                  _selectedPointIndex = i;
                });
                return;
              }
            }
            setState(() {
              _selectedWaypoint = null;
              _selectedPointIndex = -1;
            });
          },
          onPanStart: (details) {
            for (Waypoint w in widget.path.waypoints.reversed) {
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
              int index = widget.path.waypoints.indexOf(_draggedPoint!);
              Waypoint dragEnd = _draggedPoint!.clone();
              UndoRedo.addChange(Change(
                _dragOldValue,
                () {
                  setState(() {
                    if (widget.path.waypoints[index] != _draggedPoint) {
                      widget.path.waypoints[index] = dragEnd.clone();
                    }
                    widget.savePath(widget.path);
                  });
                },
                (oldValue) {
                  setState(() {
                    widget.path.waypoints[index] = oldValue.clone();
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
                    ),
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
      setState(() {
        _selectedPointIndex = -1;
        _selectedWaypoint = null;
      });
    }

    return WaypointCard(
      waypoint: _selectedWaypoint,
      stackKey: _key,
      label: waypointLabel,
      holonomicEnabled: widget.holonomicMode,
      deleteEnabled: widget.path.waypoints.length > 2,
      prefs: widget.prefs,
      onDelete: () {
        int delIndex = widget.path.waypoints.indexOf(_selectedWaypoint!);
        UndoRedo.addChange(Change(
          RobotPath.cloneWaypointList(widget.path.waypoints),
          () {
            setState(() {
              Waypoint w = widget.path.waypoints.removeAt(delIndex);
              if (w.isEndPoint()) {
                widget.path.waypoints[widget.path.waypoints.length - 1]
                    .nextControl = null;
                widget.path.waypoints[widget.path.waypoints.length - 1]
                    .isReversal = false;
                widget.path.waypoints[widget.path.waypoints.length - 1]
                    .isStopPoint = false;
                widget.path.waypoints[widget.path.waypoints.length - 1]
                    .holonomicAngle ??= 0;
              } else if (w.isStartPoint()) {
                widget.path.waypoints[0].prevControl = null;
                widget.path.waypoints[0].isReversal = false;
                widget.path.waypoints[0].isStopPoint = false;
                widget.path.waypoints[0].holonomicAngle ??= 0;
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
        setState(() {
          _selectedWaypoint = null;
        });
      },
      onShouldSave: () {
        widget.savePath(widget.path);
      },
    );
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
  final Waypoint? selectedWaypoint;

  static double scale = 1;

  _EditPainter(this.path, this.fieldImage, this.robotSize, this.holonomicMode,
      this.selectedWaypoint);

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    if (holonomicMode) {
      PathPainterUtil.paintCenterPath(
          path, canvas, scale, Colors.grey[300]!, fieldImage);
    } else {
      PathPainterUtil.paintDualPaths(
          path, robotSize, canvas, scale, Colors.grey[300]!, fieldImage);
    }

    for (Waypoint w in path.waypoints) {
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
