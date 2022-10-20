import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/services/generator/trajectory.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';

class PathFollowingEditor extends StatelessWidget {
  final FieldImage fieldImage;
  final Size robotSize;
  final List<Point>? activePath;
  final TrajectoryState? targetPose;
  final TrajectoryState? actualPose;

  const PathFollowingEditor(
      {required this.fieldImage,
      required this.robotSize,
      this.activePath,
      this.targetPose,
      this.actualPose,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Stack(
                children: [
                  fieldImage.getWidget(),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PathFollowingPainter(
                        fieldImage,
                        robotSize,
                        activePath,
                        targetPose,
                        actualPose,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PathFollowingPainter extends CustomPainter {
  final FieldImage fieldImage;
  final Size robotSize;
  final List<Point>? activePath;
  final TrajectoryState? targetPose;
  final TrajectoryState? actualPose;

  static double scale = 1;

  _PathFollowingPainter(this.fieldImage, this.robotSize, this.activePath,
      this.targetPose, this.actualPose);

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    if (activePath != null) {
      _paintActivePath(canvas);
    }

    if (targetPose != null) {
      _paintPreviewOutline(canvas, targetPose!, Colors.grey[700]!);
    }

    if (actualPose != null) {
      _paintPreviewOutline(canvas, actualPose!, Colors.grey[300]!);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void _paintActivePath(Canvas canvas) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[700]!
      ..strokeWidth = 2;

    Path path = Path();
    Offset p0 =
        PathPainterUtil.pointToPixelOffset(activePath![0], scale, fieldImage);
    path.moveTo(p0.dx, p0.dy);

    for (int i = 1; i < activePath!.length; i++) {
      Offset p =
          PathPainterUtil.pointToPixelOffset(activePath![i], scale, fieldImage);
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, paint);
  }

  void _paintPreviewOutline(Canvas canvas, TrajectoryState state, Color color) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    Offset center = PathPainterUtil.pointToPixelOffset(
        state.translationMeters, scale, fieldImage);
    num angle = -state.headingRadians;
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
