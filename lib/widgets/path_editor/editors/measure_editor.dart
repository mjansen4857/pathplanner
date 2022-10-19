import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/generator/geometry_util.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:pathplanner/widgets/path_editor/cards/simple_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeasureEditor extends StatefulWidget {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final SharedPreferences prefs;

  const MeasureEditor(
      {required this.path,
      required this.fieldImage,
      required this.robotSize,
      required this.holonomicMode,
      required this.prefs,
      super.key});

  @override
  State<MeasureEditor> createState() => _MeasureEditorState();
}

class _MeasureEditorState extends State<MeasureEditor> {
  Point? _measureStart;
  Point? _measureEnd;
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
              onPanStart: (DragStartDetails details) {
                setState(() {
                  _measureStart = Point(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy));
                  _measureEnd = null;
                });
              },
              onPanUpdate: (DragUpdateDetails details) {
                setState(() {
                  _measureEnd = Point(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy));
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Stack(
                  children: [
                    widget.fieldImage.getWidget(),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MeasurePainter(
                          widget.path,
                          widget.fieldImage,
                          widget.robotSize,
                          widget.holonomicMode,
                          _measureStart,
                          _measureEnd,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildPathLengthCard(),
      ],
    );
  }

  Widget _buildPathLengthCard() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SimpleCard(
      stackKey: _key,
      prefs: widget.prefs,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Ruler Length: ${_getRulerLength().toStringAsFixed(2)}m',
            style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
          ),
          Text(
            'Path Length: ${widget.path.generatedTrajectory.getLength().toStringAsFixed(2)}m',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  double _getRulerLength() {
    if (_measureStart != null && _measureEnd != null) {
      return _measureStart!.distanceTo(_measureEnd!);
    }

    return 0;
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels - 48) / _MeasurePainter.scale) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _yPixelsToMeters(double pixels) {
    return (widget.fieldImage.defaultSize.height -
            ((pixels - 48) / _MeasurePainter.scale)) /
        widget.fieldImage.pixelsPerMeter;
  }
}

class _MeasurePainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final Point? measureStart;
  final Point? measureEnd;

  static double scale = 1;

  _MeasurePainter(this.path, this.fieldImage, this.robotSize,
      this.holonomicMode, this.measureStart, this.measureEnd);

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    if (holonomicMode) {
      PathPainterUtil.paintCenterPath(
          path, canvas, scale, Colors.grey[700]!, fieldImage);
    } else {
      PathPainterUtil.paintDualPaths(
          path, robotSize, canvas, scale, Colors.grey[700]!, fieldImage);
    }

    for (EventMarker marker in path.markers) {
      PathPainterUtil.paintMarker(
          canvas,
          PathPainterUtil.getMarkerLocation(marker, path, fieldImage, scale),
          Colors.grey[700]!);
    }

    _paintWaypoints(canvas);
    _paintMeasureLine(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void _paintWaypoints(Canvas canvas) {
    for (Waypoint waypoint in path.waypoints) {
      Color color =
          waypoint.isStopPoint ? Colors.deepPurple : Colors.grey[400]!;
      PathPainterUtil.paintRobotOutline(
          waypoint, robotSize, holonomicMode, canvas, scale, color, fieldImage);

      var paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.grey[500]!;

      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              waypoint.anchorPoint, scale, fieldImage),
          PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
          paint);
    }
  }

  void _paintMeasureLine(Canvas canvas) {
    if (measureStart != null && measureEnd != null) {
      Offset measureStartPx =
          PathPainterUtil.pointToPixelOffset(measureStart!, scale, fieldImage);
      Offset measureEndPx =
          PathPainterUtil.pointToPixelOffset(measureEnd!, scale, fieldImage);

      var paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.grey[400]!
        ..strokeWidth = 2;

      num lineLength = sqrt(pow(measureStartPx.dx - measureEndPx.dx, 2) +
          pow(measureStartPx.dy - measureEndPx.dy, 2));

      for (num pos = 0; pos < lineLength; pos += 16) {
        num startT = pos / lineLength;
        num endT = (pos < lineLength - 8) ? (pos + 8) / lineLength : 1.0;

        Offset start =
            GeometryUtil.offsetLerp(measureStartPx, measureEndPx, startT);
        Offset end =
            GeometryUtil.offsetLerp(measureStartPx, measureEndPx, endT);

        canvas.drawLine(start, end, paint);
      }

      paint.style = PaintingStyle.fill;
      paint.color = Colors.grey[300]!;

      canvas.drawCircle(measureStartPx, 3, paint);
      canvas.drawCircle(measureEndPx, 3, paint);
    }
  }
}
