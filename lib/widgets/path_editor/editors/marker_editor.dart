import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/generator/geometry_util.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/cards/marker_card.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarkerEditor extends StatefulWidget {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final void Function(RobotPath path)? savePath;
  final SharedPreferences? prefs;

  const MarkerEditor(
      this.path, this.fieldImage, this.robotSize, this.holonomicMode,
      {this.savePath, this.prefs, Key? key})
      : super(key: key);

  @override
  State<MarkerEditor> createState() => _MarkerEditorState();
}

class _MarkerEditorState extends State<MarkerEditor> {
  EventMarker? _selectedMarker;
  GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
              onTapUp: (TapUpDetails details) {
                for (EventMarker marker in widget.path.markers) {
                  Offset markerPosPx = _MarkerPainter._getMarkerLocation(
                      marker, widget.path, widget.fieldImage);
                  Offset markerCenterPx =
                      markerPosPx - const Offset(-48, 20 - 48);

                  if ((details.localPosition - markerCenterPx).distance <= 40) {
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
    );
  }

  Widget _buildMarkerCard() {
    return MarkerCard(
      _key,
      key: ValueKey(_selectedMarker),
      prefs: widget.prefs,
      marker: _selectedMarker,
      maxMarkerPos: widget.path.waypoints.length - 1,
      onDelete: () {
        widget.path.markers.remove(_selectedMarker);
        if (widget.savePath != null) {
          widget.savePath!.call(widget.path);
        }
        setState(() {
          _selectedMarker = null;
        });
      },
      onAdd: (EventMarker newMarker) {
        widget.path.markers.add(newMarker);
        if (widget.savePath != null) {
          widget.savePath!.call(widget.path);
        }

        setState(() {
          _selectedMarker = newMarker;
        });
      },
      onSave: () {
        if (widget.savePath != null) {
          widget.savePath!.call(widget.path);
        }
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

  final IconData markerIcon = Icons.location_on;

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
        _drawMarker(canvas, _getMarkerLocation(marker, path, fieldImage),
            Colors.orange);
      } else {
        _drawMarker(canvas, _getMarkerLocation(marker, path, fieldImage),
            Colors.grey[300]!);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void _drawMarker(Canvas canvas, Offset location, Color color) {
    TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(markerIcon.codePoint),
        style: TextStyle(
          fontSize: 40,
          color: color,
          fontFamily: markerIcon.fontFamily,
        ),
      ),
    );

    TextPainter textStrokePainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(markerIcon.codePoint),
        style: TextStyle(
          fontSize: 40,
          fontFamily: markerIcon.fontFamily,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black,
        ),
      ),
    );

    textPainter.layout();
    textStrokePainter.layout();

    textPainter.paint(canvas, location - Offset(20, 37));
    textStrokePainter.paint(canvas, location - Offset(20, 37));
  }

  static Offset _getMarkerLocation(
      EventMarker marker, RobotPath path, FieldImage fieldImage) {
    int startIndex = marker.position.floor();
    double t = marker.position % 1;

    if (startIndex == path.waypoints.length - 1) {
      startIndex--;
      t = 1;
    }
    Waypoint start = path.waypoints[startIndex];
    Waypoint end = path.waypoints[startIndex + 1];

    Point markerPosMeters = GeometryUtil.cubicLerp(start.anchorPoint,
        start.nextControl!, end.prevControl!, end.anchorPoint, t);

    return PathPainterUtil.pointToPixelOffset(
        markerPosMeters, scale, fieldImage);
  }
}
