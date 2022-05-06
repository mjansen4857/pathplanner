import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/services/generator/trajectory.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/generator_settings_card.dart';
import 'package:pathplanner/widgets/path_editor/path_info_card.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreviewEditor extends StatefulWidget {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final void Function(RobotPath path)? savePath;
  final SharedPreferences? prefs;

  const PreviewEditor(
      this.path, this.fieldImage, this.robotSize, this.holonomicMode,
      {this.savePath, this.prefs, Key? key})
      : super(key: key);

  @override
  State<PreviewEditor> createState() => _PreviewEditorState();
}

class _PreviewEditorState extends State<PreviewEditor>
    with SingleTickerProviderStateMixin {
  AnimationController? _previewController;
  GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _previewController = AnimationController(vsync: this);
    _previewController!.duration = Duration(
        milliseconds:
            (widget.path.generatedTrajectory!.getRuntime() * 1000).toInt());
    _previewController!.repeat();
  }

  @override
  void dispose() {
    _previewController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.path.generatedTrajectory == null) {
      _regeneratePath();
    }

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
                          painter: _PreviewPainter(
                            widget.path,
                            widget.fieldImage,
                            widget.robotSize,
                            widget.holonomicMode,
                            _previewController!.view,
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
        _buildGeneratorSettingsCard(),
        _buildPathInfo(),
      ],
    );
  }

  Widget _buildGeneratorSettingsCard() {
    return GeneratorSettingsCard(
      widget.path,
      _key,
      onShouldSave: () async {
        await widget.path.generateTrajectory();

        _previewController!.stop();
        _previewController!.reset();
        _previewController!.duration = Duration(
            milliseconds:
                (widget.path.generatedTrajectory!.getRuntime() * 1000).toInt());
        _previewController!.repeat();

        if (widget.savePath != null) {
          widget.savePath!.call(widget.path);
        }
      },
      prefs: widget.prefs,
    );
  }

  Widget _buildPathInfo() {
    return PathInfoCard(
      widget.path,
      _key,
      prefs: widget.prefs,
    );
  }

  void _regeneratePath() {
    widget.path.generateTrajectory().whenComplete(() {
      _previewController!.duration = Duration(
          milliseconds:
              (widget.path.generatedTrajectory!.getRuntime() * 1000).toInt());
      setState(() {
        _previewController!.reset();
        _previewController!.repeat();
      });
    });
  }
}

class _PreviewPainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  Animation<num>? previewTime;

  static double scale = 1;

  _PreviewPainter(this.path, this.fieldImage, this.robotSize,
      this.holonomicMode, Animation<double>? animation)
      : super(repaint: animation) {
    if (animation != null && path.generatedTrajectory != null) {
      previewTime =
          Tween<num>(begin: 0, end: path.generatedTrajectory!.getRuntime())
              .animate(animation);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    PathPainterUtil.paintCenterPath(
        path, canvas, scale, Colors.grey[700]!, fieldImage);
    if (path.generatedTrajectory != null && previewTime != null) {
      _paintPreviewOutline(
          canvas, path.generatedTrajectory!.sample(previewTime!.value));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void _paintPreviewOutline(Canvas canvas, TrajectoryState state) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]!
      ..strokeWidth = 2;

    Offset center = PathPainterUtil.pointToPixelOffset(
        state.translationMeters, scale, fieldImage);
    num angle = (holonomicMode)
        ? (-state.holonomicRotation / 180 * pi)
        : -state.headingRadians;
    double halfWidth =
        PathPainterUtil.metersToPixels(robotSize.width / 2, scale, fieldImage);
    double halfLength =
        PathPainterUtil.metersToPixels(robotSize.height / 2, scale, fieldImage);

    Offset l = Offset(center.dx + (halfWidth * sin(angle)),
        center.dy - (halfWidth * cos(angle)));
    Offset r = Offset(center.dx - (halfWidth * sin(angle)),
        center.dy + (halfWidth * cos(angle)));

    Offset frontLeft = Offset(
        l.dx + (halfLength * cos(angle)), l.dy + (halfLength * sin(angle)));
    Offset backLeft = Offset(
        l.dx - (halfLength * cos(angle)), l.dy - (halfLength * sin(angle)));
    Offset frontRight = Offset(
        r.dx + (halfLength * cos(angle)), r.dy + (halfLength * sin(angle)));
    Offset backRight = Offset(
        r.dx - (halfLength * cos(angle)), r.dy - (halfLength * sin(angle)));

    canvas.drawLine(backLeft, frontLeft, paint);
    canvas.drawLine(frontLeft, frontRight, paint);
    canvas.drawLine(frontRight, backRight, paint);
    canvas.drawLine(backRight, backLeft, paint);

    Offset frontMiddle = frontLeft + ((frontRight - frontLeft) * 0.5);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(frontMiddle,
        PathPainterUtil.metersToPixels(0.075, scale, fieldImage), paint);
  }
}
