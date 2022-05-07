import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:pathplanner/widgets/path_editor/simple_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeasureEditor extends StatefulWidget {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final SharedPreferences? prefs;

  const MeasureEditor(
      this.path, this.fieldImage, this.robotSize, this.holonomicMode,
      {this.prefs, Key? key})
      : super(key: key);

  @override
  State<MeasureEditor> createState() => _MeasureEditorState();
}

class _MeasureEditorState extends State<MeasureEditor> {
  GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Center(
          child: InteractiveViewer(
            child: Container(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Stack(
                  children: [
                    widget.fieldImage,
                    Positioned.fill(
                      child: Container(
                        child: CustomPaint(
                          painter: _MeasurePainter(
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
        _buildPathLengthCard(),
      ],
    );
  }

  Widget _buildPathLengthCard() {
    return SimpleCard(
      'Path Length: ${widget.path.generatedTrajectory.getLength().toStringAsFixed(2)}m',
      _key,
      prefs: widget.prefs,
    );
  }
}

class _MeasurePainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;

  static double scale = 1;

  _MeasurePainter(
      this.path, this.fieldImage, this.robotSize, this.holonomicMode);

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

    _paintWaypoints(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void _paintWaypoints(Canvas canvas) {
    for (Waypoint waypoint in path.waypoints) {
      PathPainterUtil.paintRobotOutline(waypoint, robotSize, holonomicMode,
          canvas, scale, Colors.grey[400]!, fieldImage);

      var paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.grey[500]!;

      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              waypoint.anchorPoint, scale, fieldImage),
          PathPainterUtil.metersToPixels(0.1, scale, fieldImage),
          paint);
    }
  }
}
