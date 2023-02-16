import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/path_editor/cards/marker_card.dart';
import 'package:pathplanner/widgets/path_editor/cards/stop_event_card.dart';
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
  Waypoint? _selectedStopEventWaypoint;
  double? _markerPreviewPos;
  final GlobalKey _key = GlobalKey();

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
          _selectedStopEventWaypoint = null;
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
            _selectedStopEventWaypoint = null;
          });
          UndoRedo.redo();
        },
        child: KeyBoardShortcuts(
          keysToPress: Platform.isMacOS
              ? {LogicalKeyboardKey.meta, LogicalKeyboardKey.backspace}
              : {LogicalKeyboardKey.delete},
          onKeysPressed: () {
            if (_selectedMarker != null) {
              _deleteMarker();
            }
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
                            _selectedStopEventWaypoint = null;
                          });
                          return;
                        }
                      }
                      for (Waypoint waypoint in widget.path.waypoints) {
                        if (waypoint.isStopPoint ||
                            waypoint.isStartPoint() ||
                            waypoint.isEndPoint()) {
                          Offset markerPosPx =
                              PathPainterUtil.pointToPixelOffset(
                                  waypoint.anchorPoint,
                                  _MarkerPainter.scale,
                                  widget.fieldImage);
                          Offset markerCenterPx =
                              markerPosPx - const Offset(-48, 20 - 48);

                          if ((details.localPosition - markerCenterPx)
                                  .distance <=
                              40) {
                            setState(() {
                              _selectedMarker = null;
                              _selectedStopEventWaypoint = waypoint;
                            });
                            return;
                          }
                        }
                      }
                      setState(() {
                        _selectedMarker = null;
                        _selectedStopEventWaypoint = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Stack(
                        children: [
                          widget.fieldImage.getWidget(),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _MarkerPainter(
                                widget.path,
                                widget.fieldImage,
                                widget.robotSize,
                                widget.holonomicMode,
                                _selectedMarker,
                                _selectedStopEventWaypoint,
                                _markerPreviewPos,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildMarkerCard(),
              _buildStopEventCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopEventCard() {
    return Visibility(
      visible: _selectedStopEventWaypoint != null,
      child: StopEventCard(
        stackKey: _key,
        key: ValueKey(_selectedStopEventWaypoint),
        prefs: widget.prefs,
        stopEvent: _selectedStopEventWaypoint?.stopEvent,
        onEdited: (oldEvent) {
          UndoRedo.addChange(
            CustomChange(
              [
                _selectedStopEventWaypoint!.stopEvent.clone(),
                oldEvent.clone(),
              ],
              (oldValue) {
                int index = widget.path.waypoints
                    .indexWhere((element) => element.stopEvent == oldValue[1]);

                if (index != -1) {
                  widget.path.waypoints[index].stopEvent = oldValue[0].clone();
                }

                widget.savePath(widget.path);
              },
              (oldValue) {
                int index = widget.path.waypoints
                    .indexWhere((element) => element.stopEvent == oldValue[0]);

                if (index != -1) {
                  widget.path.waypoints[index].stopEvent = oldValue[1].clone();
                }

                widget.savePath(widget.path);
              },
            ),
          );
        },
        onPrevStopEvent:
            _selectedStopEventWaypoint != widget.path.waypoints.first
                ? () {
                    for (int i = widget.path.waypoints
                                .indexOf(_selectedStopEventWaypoint!) -
                            1;
                        i >= 0;
                        i--) {
                      Waypoint w = widget.path.waypoints[i];
                      if (w.isStopPoint || w.isEndPoint() || w.isStartPoint()) {
                        setState(() {
                          _selectedStopEventWaypoint = w;
                        });
                        break;
                      }
                    }
                  }
                : null,
        onNextStopEvent:
            _selectedStopEventWaypoint != widget.path.waypoints.last
                ? () {
                    for (int i = widget.path.waypoints
                                .indexOf(_selectedStopEventWaypoint!) +
                            1;
                        i < widget.path.waypoints.length;
                        i++) {
                      Waypoint w = widget.path.waypoints[i];
                      if (w.isStopPoint || w.isEndPoint() || w.isStartPoint()) {
                        setState(() {
                          _selectedStopEventWaypoint = w;
                        });
                        break;
                      }
                    }
                  }
                : null,
      ),
    );
  }

  void _deleteMarker() {
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
          _selectedStopEventWaypoint = null;
          _markerPreviewPos = null;
        });
      },
      (oldValue) {
        // Undo
        widget.path.markers = RobotPath.cloneMarkerList(oldValue[0]);
        widget.savePath(widget.path);
        setState(() {
          _selectedMarker = oldValue[1];
          _selectedStopEventWaypoint = null;
          _markerPreviewPos = null;
        });
      },
    ));
  }

  Widget _buildMarkerCard() {
    return Visibility(
      visible: _selectedStopEventWaypoint == null,
      child: MarkerCard(
        stackKey: _key,
        key: ValueKey(_selectedMarker),
        prefs: widget.prefs,
        path: widget.path,
        marker: _selectedMarker,
        maxMarkerPos: widget.path.waypoints.length - 1,
        onDelete: _deleteMarker,
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
                _selectedStopEventWaypoint = null;
                _markerPreviewPos = null;
              });
            },
            (oldValue) {
              widget.path.markers = RobotPath.cloneMarkerList(oldValue[0]);
              widget.savePath(widget.path);

              setState(() {
                _selectedMarker = null;
                _selectedStopEventWaypoint = null;
                _markerPreviewPos = null;
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
        onPreviewPosChanged: (value) {
          setState(() {
            _markerPreviewPos = value;
          });
        },
        onPrevMarker: widget.path.markers.isNotEmpty &&
                _selectedMarker != widget.path.markers.first
            ? () {
                setState(() {
                  _selectedMarker = widget.path.markers[
                      widget.path.markers.indexOf(_selectedMarker!) - 1];
                });
              }
            : null,
        onNextMarker: widget.path.markers.isNotEmpty &&
                _selectedMarker != widget.path.markers.last
            ? () {
                setState(() {
                  _selectedMarker = widget.path.markers[
                      widget.path.markers.indexOf(_selectedMarker!) + 1];
                });
              }
            : null,
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final EventMarker? selectedMarker;
  final Waypoint? selectedStopEventWaypoint;
  final double? markerPreviewPos;

  static double scale = 1.0;

  _MarkerPainter(
      this.path,
      this.fieldImage,
      this.robotSize,
      this.holonomicMode,
      this.selectedMarker,
      this.selectedStopEventWaypoint,
      this.markerPreviewPos);

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    if (!holonomicMode) {
      PathPainterUtil.paintDualPaths(
          path, robotSize, canvas, scale, Colors.grey[700]!, fieldImage);
    }

    for (Waypoint waypoint in path.waypoints) {
      Color color =
          waypoint.isStopPoint ? Colors.deepPurple : Colors.grey[700]!;
      PathPainterUtil.paintRobotOutline(
          waypoint, robotSize, holonomicMode, canvas, scale, color, fieldImage);
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

    for (Waypoint waypoint in path.waypoints) {
      if (waypoint.isStartPoint() ||
          waypoint.isEndPoint() ||
          waypoint.isStopPoint) {
        if (waypoint == selectedStopEventWaypoint) {
          PathPainterUtil.paintMarker(
              canvas,
              PathPainterUtil.pointToPixelOffset(
                  waypoint.anchorPoint, scale, fieldImage),
              Colors.orange);
        } else {
          PathPainterUtil.paintMarker(
              canvas,
              PathPainterUtil.pointToPixelOffset(
                  waypoint.anchorPoint, scale, fieldImage),
              Colors.deepPurple);
        }
      }
    }

    if (selectedMarker == null && markerPreviewPos != null) {
      Offset previewLocation = PathPainterUtil.getMarkerLocation(
          EventMarker(markerPreviewPos!, ['preview']), path, fieldImage, scale);

      Paint paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.orange;

      canvas.drawCircle(previewLocation, 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
