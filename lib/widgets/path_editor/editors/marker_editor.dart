import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/path_editor/cards/marker_card.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarkerEditor extends StatefulWidget {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final void Function(RobotPath path) savePath;
  final SharedPreferences prefs;

  const MarkerEditor(
      {required this.path,
      required this.fieldImage,
      required this.robotSize,
      required this.holonomicMode,
      required this.savePath,
      required this.prefs,
      super.key});

  @override
  State<MarkerEditor> createState() => _MarkerEditorState();
}

class _MarkerEditorState extends State<MarkerEditor> {
  EventMarker? _selectedMarker;
  GlobalKey _key = GlobalKey();

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
          _selectedMarker = null;
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
            _selectedMarker = null;
          });
          UndoRedo.redo();
        },
        child: Stack(
          key: _key,
          children: [
            Center(
              child: InteractiveViewer(
                child: GestureDetector(
                  onTapUp: (TapUpDetails details) {
                    for (EventMarker marker in widget.path.markers) {
                      Offset markerPosPx = PathPainterUtil.getMarkerLocation(
                          marker,
                          widget.path,
                          widget.fieldImage,
                          _MarkerPainter.scale);
                      Offset markerCenterPx =
                          markerPosPx - const Offset(-48, 20 - 48);

                      if ((details.localPosition - markerCenterPx).distance <=
                          40) {
                        setState(() {
                          _selectedMarker = marker;
                        });
                        return;
                      }
                    }
                    setState(() {
                      _selectedMarker = null;
                    });
                  },
                  child: Container(
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Stack(
                        children: [
                          widget.fieldImage,
                          Positioned.fill(
                            child: Container(
                              child: CustomPaint(
                                painter: _MarkerPainter(
                                  widget.path,
                                  widget.fieldImage,
                                  widget.robotSize,
                                  widget.holonomicMode,
                                  _selectedMarker,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildMarkerCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerCard() {
    return MarkerCard(
      stackKey: _key,
      key: ValueKey(_selectedMarker),
      prefs: widget.prefs,
      marker: _selectedMarker,
      maxMarkerPos: widget.path.waypoints.length - 1,
      onDelete: () {
        UndoRedo.addChange(CustomChange(
          [
            RobotPath.cloneMarkerList(widget.path.markers),
            _selectedMarker,
          ],
          (oldValue) {
            // Execute
            widget.path.markers.remove(oldValue[1]);
            widget.savePath(widget.path);
            setState(() {
              _selectedMarker = null;
            });
          },
          (oldValue) {
            // Undo
            widget.path.markers = RobotPath.cloneMarkerList(oldValue[0]);
            widget.savePath(widget.path);
            setState(() {
              _selectedMarker = oldValue[1];
            });
          },
        ));
      },
      onAdd: (EventMarker newMarker) {
        UndoRedo.addChange(CustomChange(
          [
            RobotPath.cloneMarkerList(widget.path.markers),
            newMarker,
          ],
          (oldValue) {
            widget.path.markers.add(oldValue[1]);
            widget.savePath(widget.path);

            setState(() {
              _selectedMarker = oldValue[1];
            });
          },
          (oldValue) {
            widget.path.markers = RobotPath.cloneMarkerList(oldValue[0]);
            widget.savePath(widget.path);

            setState(() {
              _selectedMarker = null;
            });
          },
        ));
      },
      onEdited: (EventMarker oldMarker) {
        UndoRedo.addChange(CustomChange(
          [
            _selectedMarker!.clone(),
            oldMarker.clone(),
          ],
          (oldValue) {
            int index = widget.path.markers.indexOf(oldValue[1]);
            if (index != -1) {
              widget.path.markers[index] = oldValue[0].clone();
            }

            widget.savePath(widget.path);
          },
          (oldValue) {
            int index = widget.path.markers.indexOf(oldValue[0]);
            if (index != -1) {
              widget.path.markers[index] = oldValue[1].clone();
            }

            widget.savePath(widget.path);
          },
        ));
      },
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final EventMarker? selectedMarker;

  static double scale = 1.0;

  _MarkerPainter(this.path, this.fieldImage, this.robotSize, this.holonomicMode,
      this.selectedMarker);

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    if (!holonomicMode) {
      PathPainterUtil.paintDualPaths(
          path, robotSize, canvas, scale, Colors.grey[700]!, fieldImage);
    }

    for (Waypoint waypoint in path.waypoints) {
      PathPainterUtil.paintRobotOutline(waypoint, robotSize, holonomicMode,
          canvas, scale, Colors.grey[700]!, fieldImage);
    }

    PathPainterUtil.paintCenterPath(
        path, canvas, scale, Colors.grey[400]!, fieldImage);

    for (EventMarker marker in path.markers) {
      if (marker == selectedMarker) {
        PathPainterUtil.paintMarker(
            canvas,
            PathPainterUtil.getMarkerLocation(marker, path, fieldImage, scale),
            Colors.orange);
      } else {
        PathPainterUtil.paintMarker(
            canvas,
            PathPainterUtil.getMarkerLocation(marker, path, fieldImage, scale),
            Colors.grey[300]!);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
