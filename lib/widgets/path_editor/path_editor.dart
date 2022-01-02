import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/path_editor/generator_settings_card.dart';
import 'package:pathplanner/widgets/path_editor/waypoint_card.dart';
import 'package:undo/undo.dart';

import 'path_painter.dart';

class PathEditor extends StatefulWidget {
  final RobotPath path;
  final double robotWidth;
  final double robotLength;
  final bool holonomicMode;
  final bool generateJSON;
  final bool generateCSV;
  final String pathsDir;

  PathEditor(this.path, this.robotWidth, this.robotLength, this.holonomicMode,
      this.generateJSON, this.generateCSV, this.pathsDir);

  @override
  _PathEditorState createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  Waypoint? _draggedPoint;
  Waypoint? _selectedPoint;
  Waypoint? _dragOldValue;

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
          _selectedPoint = null;
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
            _selectedPoint = null;
          });
          UndoRedo.redo();
        },
        child: Stack(
          children: [
            _buildEditor(),
            _buildWaypointCard(),
            _buildWPILibSettingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Center(
      child: InteractiveViewer(
        child: GestureDetector(
          onDoubleTapDown: (details) {
            UndoRedo.addChange(Change(
              RobotPath.cloneWaypointList(widget.path.waypoints),
              () {
                setState(() {
                  widget.path.addWaypoint(Point(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy)));
                  widget.path.savePath(
                      widget.pathsDir, widget.generateJSON, widget.generateCSV);
                });
              },
              (oldValue) {
                setState(() {
                  widget.path.waypoints.removeLast();
                  widget.path.waypoints.last.nextControl = null;
                  widget.path.savePath(
                      widget.pathsDir, widget.generateJSON, widget.generateCSV);
                });
              },
            ));
            setState(() {
              _selectedPoint =
                  widget.path.waypoints[widget.path.waypoints.length - 1];
            });
          },
          onDoubleTap: () {},
          onTapDown: (details) {
            FocusScopeNode currentScope = FocusScope.of(context);
            if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
              FocusManager.instance.primaryFocus!.unfocus();
            }
            for (Waypoint w in widget.path.waypoints.reversed) {
              if (w.isPointInAnchor(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      _pixelsToMeters(8)) ||
                  w.isPointInNextControl(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      _pixelsToMeters(6)) ||
                  w.isPointInPrevControl(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      _pixelsToMeters(6)) ||
                  w.isPointInHolonomicThing(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      _pixelsToMeters(5),
                      widget.robotLength)) {
                setState(() {
                  _selectedPoint = w;
                });
                return;
              }
            }
            setState(() {
              _selectedPoint = null;
            });
          },
          onPanStart: (details) {
            for (Waypoint w in widget.path.waypoints.reversed) {
              if (w.startDragging(
                  _xPixelsToMeters(details.localPosition.dx),
                  _yPixelsToMeters(details.localPosition.dy),
                  _pixelsToMeters(8),
                  _pixelsToMeters(6),
                  _pixelsToMeters(5),
                  widget.robotLength,
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
                    _xPixelsToMeters(details.localPosition.dx),
                    _yPixelsToMeters(details.localPosition.dy));
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
                    widget.path.savePath(widget.pathsDir, widget.generateJSON,
                        widget.generateCSV);
                  });
                },
                (oldValue) {
                  setState(() {
                    widget.path.waypoints[index] = oldValue.clone();
                    widget.path.savePath(widget.pathsDir, widget.generateJSON,
                        widget.generateCSV);
                  });
                },
              ));
              _draggedPoint = null;
            }
          },
          child: Container(
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2 / 1,
                  child: SizedBox.expand(
                    child: Image.asset(
                      'images/field20.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    child: CustomPaint(
                      painter: PathPainter(
                          widget.path,
                          Size(widget.robotWidth, widget.robotLength),
                          widget.holonomicMode,
                          _selectedPoint),
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
    return Align(
      alignment: FractionalOffset.topRight,
      child: WaypointCard(
        _selectedPoint,
        label: widget.path.getWaypointLabel(_selectedPoint),
        holonomicEnabled: widget.holonomicMode,
        deleteEnabled: widget.path.waypoints.length > 2,
        onShouldSave: () {
          widget.path.savePath(
              widget.pathsDir, widget.generateJSON, widget.generateCSV);
        },
        onDelete: () {
          int delIndex = widget.path.waypoints.indexOf(_selectedPoint!);
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
                } else if (w.isStartPoint()) {
                  widget.path.waypoints[0].prevControl = null;
                  widget.path.waypoints[0].isReversal = false;
                }
                widget.path.savePath(
                    widget.pathsDir, widget.generateJSON, widget.generateCSV);
              });
            },
            (oldValue) {
              setState(() {
                widget.path.waypoints = RobotPath.cloneWaypointList(oldValue);
                widget.path.savePath(
                    widget.pathsDir, widget.generateJSON, widget.generateCSV);
              });
            },
          ));
          setState(() {
            _selectedPoint = null;
          });
        },
      ),
    );
  }

  Widget _buildWPILibSettingsCard() {
    return Visibility(
      visible: widget.generateJSON,
      child: Align(
        alignment: FractionalOffset.bottomLeft,
        child: GeneratorSettingsCard(
          widget.path,
          onShouldSave: () {
            widget.path.savePath(
                widget.pathsDir, widget.generateJSON, widget.generateCSV);
          },
        ),
      ),
    );
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels / PathPainter.scale) - 76) / 66.11;
  }

  double _yPixelsToMeters(double pixels) {
    return (600 - (pixels / PathPainter.scale) - 78) / 66.11;
  }

  double _pixelsToMeters(double pixels) {
    return pixels / 66.11 / PathPainter.scale;
  }
}
