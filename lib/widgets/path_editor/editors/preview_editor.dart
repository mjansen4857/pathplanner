import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/services/generator/trajectory.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/cards/generator_settings_card.dart';
import 'package:pathplanner/widgets/path_editor/cards/simple_card.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreviewEditor extends StatefulWidget {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final void Function(RobotPath path) savePath;
  final SharedPreferences prefs;

  const PreviewEditor(
      {required this.path,
      required this.fieldImage,
      required this.robotSize,
      required this.holonomicMode,
      required this.savePath,
      required this.prefs,
      super.key});

  @override
  State<PreviewEditor> createState() => _PreviewEditorState();
}

class _PreviewEditorState extends State<PreviewEditor>
    with SingleTickerProviderStateMixin {
  late AnimationController _previewController;
  final GlobalKey _key = GlobalKey();
  UniqueKey _pathRuntimeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _previewController = AnimationController(vsync: this);
    _previewController.duration = Duration(
        milliseconds:
            (widget.path.generatedTrajectory.getRuntime() * 1000).toInt());
    _previewController.repeat();
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Center(
          child: InteractiveViewer(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Stack(
                children: [
                  widget.fieldImage.getWidget(),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PreviewPainter(
                        widget.path,
                        widget.fieldImage,
                        widget.robotSize,
                        widget.holonomicMode,
                        _previewController.view,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildGeneratorSettingsCard(),
        _buildRuntimeCard(),
      ],
    );
  }

  Widget _buildGeneratorSettingsCard() {
    return GeneratorSettingsCard(
      path: widget.path,
      holonomicMode: widget.holonomicMode,
      stackKey: _key,
      onShouldSave: () async {
        await widget.path.generateTrajectory();

        setState(() {
          // Force rebuild card to update runtime
          _pathRuntimeKey = UniqueKey();
        });

        _previewController.stop();
        _previewController.reset();
        _previewController.duration = Duration(
            milliseconds:
                (widget.path.generatedTrajectory.getRuntime() * 1000).toInt());
        _previewController.repeat();

        widget.savePath(widget.path);
      },
      prefs: widget.prefs,
    );
  }

  Widget _buildRuntimeCard() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SimpleCard(
      stackKey: _key,
      prefs: widget.prefs,
      key: _pathRuntimeKey,
      child: Text(
        'Total Runtime: ${widget.path.generatedTrajectory.getRuntime().toStringAsFixed(2)}s',
        style: TextStyle(color: colorScheme.onSurface),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  late final Animation<num> previewTime;

  static double scale = 1;

  _PreviewPainter(this.path, this.fieldImage, this.robotSize,
      this.holonomicMode, Animation<double> animation)
      : super(repaint: animation) {
    previewTime =
        Tween<num>(begin: 0, end: path.generatedTrajectory.getRuntime())
            .animate(animation);
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    PathPainterUtil.paintCenterPath(
        path, canvas, scale, Colors.grey[700]!, fieldImage);

    for (EventMarker marker in path.markers) {
      PathPainterUtil.paintMarker(
          canvas,
          PathPainterUtil.getMarkerLocation(marker, path, fieldImage, scale),
          Colors.grey[700]!);
    }

    _paintPreviewOutline(
        canvas, path.generatedTrajectory.sample(previewTime.value));
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
        PathPainterUtil.uiPointSizeToPixels(15, scale, fieldImage), paint);
  }
}
