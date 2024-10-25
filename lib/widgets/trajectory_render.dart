import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrajectoryRender extends StatelessWidget {
  final FieldImage fieldImage;
  final SharedPreferences prefs;
  final PathPlannerTrajectory trajectory;
  final num? sampleTime;

  const TrajectoryRender({
    super.key,
    required this.fieldImage,
    required this.prefs,
    required this.trajectory,
    required this.sampleTime,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fieldImage.defaultSize.width / 4,
      height: fieldImage.defaultSize.height / 4,
      child: Center(
        child: Stack(
          children: [
            fieldImage.getWidget(),
            Positioned.fill(
              child: CustomPaint(
                painter: TrajectoryPainter(
                  colorScheme: Theme.of(context).colorScheme,
                  trajectory: trajectory,
                  sampleTime: sampleTime,
                  fieldImage: fieldImage,
                  prefs: prefs,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrajectoryPainter extends CustomPainter {
  final ColorScheme colorScheme;
  final FieldImage fieldImage;
  final PathPlannerTrajectory trajectory;
  final SharedPreferences prefs;
  final num? sampleTime;

  late Size robotSize;
  late num robotRadius;
  late bool holonomicMode;
  late num wheelbase;
  late num trackwidth;

  static double scale = 1;

  TrajectoryPainter({
    required this.colorScheme,
    required this.fieldImage,
    required this.trajectory,
    required this.prefs,
    required this.sampleTime,
  }) {
    double robotWidth =
        prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth;
    double robotLength =
        prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength;
    robotSize = Size(robotWidth, robotLength);
    robotRadius = sqrt((robotSize.width * robotSize.width) +
            (robotSize.height * robotSize.height)) /
        2.0;
    wheelbase =
        prefs.getDouble(PrefsKeys.robotWheelbase) ?? Defaults.robotWheelbase;
    trackwidth =
        prefs.getDouble(PrefsKeys.robotTrackwidth) ?? Defaults.robotTrackwidth;

    holonomicMode =
        prefs.getBool(PrefsKeys.holonomicMode) ?? Defaults.holonomicMode;
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    _paintTrajectory(
        trajectory,
        canvas,
        colorScheme.brightness == Brightness.dark
            ? colorScheme.secondary
            : colorScheme.primary);

    if (sampleTime == null) {
      // Paint start and end
      PathPainterUtil.paintRobotOutline(
          Pose2d(trajectory.states.first.pose.translation,
              trajectory.states.first.pose.rotation),
          fieldImage,
          robotSize,
          scale,
          canvas,
          Colors.green[700]!,
          colorScheme.surfaceContainer);
      PathPainterUtil.paintRobotOutline(
          Pose2d(trajectory.states.last.pose.translation,
              trajectory.states.last.pose.rotation),
          fieldImage,
          robotSize,
          scale,
          canvas,
          Colors.red[700]!,
          colorScheme.surfaceContainer);
    } else {
      TrajectoryState state = trajectory.sample(sampleTime!);
      Rotation2d rotation = state.pose.rotation;

      if (holonomicMode && state.moduleStates.isNotEmpty) {
        // Calculate the module positions based off of the robot position
        // so they don't move relative to the robot when interpolating
        // between trajectory states
        List<Pose2d> modPoses = [
          Pose2d(
              state.pose.translation +
                  Translation2d(wheelbase / 2, trackwidth / 2)
                      .rotateBy(rotation),
              state.moduleStates[0].fieldAngle),
          Pose2d(
              state.pose.translation +
                  Translation2d(wheelbase / 2, -trackwidth / 2)
                      .rotateBy(rotation),
              state.moduleStates[1].fieldAngle),
          Pose2d(
              state.pose.translation +
                  Translation2d(-wheelbase / 2, trackwidth / 2)
                      .rotateBy(rotation),
              state.moduleStates[2].fieldAngle),
          Pose2d(
              state.pose.translation +
                  Translation2d(-wheelbase / 2, -trackwidth / 2)
                      .rotateBy(rotation),
              state.moduleStates[3].fieldAngle),
        ];
        PathPainterUtil.paintRobotModules(
            modPoses,
            fieldImage,
            scale,
            canvas,
            colorScheme.brightness == Brightness.dark
                ? colorScheme.primary
                : colorScheme.secondary);
      }

      PathPainterUtil.paintRobotOutline(
          Pose2d(state.pose.translation, rotation),
          fieldImage,
          robotSize,
          scale,
          canvas,
          colorScheme.brightness == Brightness.dark
              ? colorScheme.primary
              : colorScheme.secondary,
          colorScheme.surfaceContainer);
    }
  }

  @override
  bool shouldRepaint(TrajectoryPainter oldDelegate) {
    return sampleTime != oldDelegate.sampleTime ||
        colorScheme != oldDelegate.colorScheme;
  }

  void _paintTrajectory(
      PathPlannerTrajectory traj, Canvas canvas, Color baseColor) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 2;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        traj.states.first.pose.translation, scale, fieldImage);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < traj.states.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          traj.states[i].pose.translation, scale, fieldImage);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);
  }
}
