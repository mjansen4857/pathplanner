import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/widgets/field_image.dart';
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
  GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
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
      ],
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;

  final IconData markerIcon = Icons.location_on;

  static double scale = 1.0;

  _MarkerPainter(
      this.path, this.fieldImage, this.robotSize, this.holonomicMode);

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

    Offset test =
        PathPainterUtil.pointToPixelOffset(Point(4.55, 3.3), scale, fieldImage);
    _drawMarker(canvas, test, Colors.grey[300]!);
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
}
