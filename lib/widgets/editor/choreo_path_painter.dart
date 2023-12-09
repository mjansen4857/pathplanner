import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/services/simulator/trajectory_generator.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChoreoPathPainter extends CustomPainter {
  final List<ChoreoPath> paths;
  final FieldImage fieldImage;
  final String? hoveredPath;
  final Trajectory? simulatedPath;
  final Color? previewColor;
  final SharedPreferences prefs;

  late Size robotSize;
  late num robotRadius;
  Animation<num>? previewTime;

  static double scale = 1;

  ChoreoPathPainter({
    required this.paths,
    required this.fieldImage,
    this.simulatedPath,
    this.hoveredPath,
    Animation<double>? animation,
    this.previewColor,
    required this.prefs,
  }) : super(repaint: animation) {
    double robotWidth =
        prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth;
    double robotLength =
        prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength;
    robotSize = Size(robotWidth, robotLength);
    robotRadius = sqrt((robotSize.width * robotSize.width) +
            (robotSize.height * robotSize.height)) /
        2.0;

    if (simulatedPath != null && animation != null) {
      previewTime = Tween<num>(begin: 0, end: simulatedPath!.states.last.time)
          .animate(animation);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    for (int i = 0; i < paths.length; i++) {
      if (paths[i].trajectory.states.isNotEmpty) {
        _paintTrajectory(paths[i].trajectory, canvas,
            (hoveredPath == paths[i].name) ? Colors.orange : Colors.grey[300]!);
        _paintWaypoint(
            paths[i].trajectory.states.first, canvas, Colors.green, scale);
        _paintWaypoint(
            paths[i].trajectory.states.last, canvas, Colors.red, scale);
      }
    }

    if (previewTime != null) {
      TrajectoryState state = simulatedPath!.sample(previewTime!.value);
      num rotation = state.holonomicRotationRadians;

      PathPainterUtil.paintRobotOutline(
          state.position,
          GeometryUtil.toDegrees(rotation),
          fieldImage,
          robotSize,
          scale,
          canvas,
          previewColor ?? Colors.grey);
    }
  }

  @override
  bool shouldRepaint(ChoreoPathPainter oldDelegate) {
    return true; // This will just be repainted all the time anyways from the animation
  }

  void _paintTrajectory(Trajectory traj, Canvas canvas, Color baseColor) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 2;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        traj.states.first.position, scale, fieldImage);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < traj.states.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          traj.states[i].position, scale, fieldImage);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);
  }

  void _paintWaypoint(
      TrajectoryState state, Canvas canvas, Color color, double scale) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(state.position, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(state.position, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);

    // Draw robot
    PathPainterUtil.paintRobotOutline(
        state.position,
        GeometryUtil.toDegrees(state.holonomicRotationRadians),
        fieldImage,
        robotSize,
        scale,
        canvas,
        color.withOpacity(0.5));
  }
}
