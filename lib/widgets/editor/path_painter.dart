import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/path/point_towards_zone.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PathPainter extends CustomPainter {
  final ColorScheme colorScheme;
  final List<PathPlannerPath> paths;
  final List<ChoreoPath> choreoPaths;
  final FieldImage fieldImage;
  final bool simple;
  final bool hideOtherPathsOnHover;
  final String? hoveredPath;
  final int? hoveredWaypoint;
  final int? selectedWaypoint;
  final int? hoveredZone;
  final int? selectedZone;
  final int? hoveredPointZone;
  final int? selectedPointZone;
  final int? hoveredRotTarget;
  final int? selectedRotTarget;
  final int? hoveredMarker;
  final int? selectedMarker;
  final PathPlannerTrajectory? simulatedPath;
  final SharedPreferences prefs;
  final PathPlannerPath? optimizedPath;

  late Size robotSize;
  late num robotRadius;
  late bool holonomicMode;
  late num wheelbase;
  late num trackwidth;
  Animation<num>? previewTime;

  static double scale = 1;

  PathPainter({
    required this.colorScheme,
    required this.paths,
    this.choreoPaths = const [],
    required this.fieldImage,
    this.simple = false,
    this.hideOtherPathsOnHover = false,
    this.hoveredPath,
    this.hoveredWaypoint,
    this.selectedWaypoint,
    this.hoveredZone,
    this.selectedZone,
    this.hoveredPointZone,
    this.selectedPointZone,
    this.hoveredRotTarget,
    this.selectedRotTarget,
    this.hoveredMarker,
    this.selectedMarker,
    this.simulatedPath,
    Animation<double>? animation,
    required this.prefs,
    this.optimizedPath,
  }) : super(repaint: animation) {
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

    if (simulatedPath != null && animation != null) {
      previewTime =
          Tween<num>(begin: 0, end: simulatedPath!.states.last.timeSeconds)
              .animate(animation);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    _paintGrid(
        canvas, size, prefs.getBool(PrefsKeys.showGrid) ?? Defaults.showGrid);

    for (int i = 0; i < paths.length; i++) {
      if (hideOtherPathsOnHover &&
          hoveredPath != null &&
          hoveredPath != paths[i].name) {
        continue;
      }

      if (!simple) {
        _paintRadius(paths[i], canvas, scale);
      }

      _paintPathPoints(
          paths[i],
          canvas,
          (hoveredPath == paths[i].name)
              ? Colors.orange
              : colorScheme.secondary);

      if (holonomicMode) {
        _paintRotations(paths[i], canvas, scale);
      }

      _paintMarkers(paths[i], canvas);

      if (!simple) {
        for (int w = 0; w < paths[i].waypoints.length; w++) {
          _paintWaypoint(paths[i], canvas, scale, w);
        }
      } else {
        _paintWaypoint(paths[i], canvas, scale, 0);
        _paintWaypoint(paths[i], canvas, scale, paths[i].waypoints.length - 1);
      }

      _paintPointZonePositions(paths[i], canvas, scale);
    }

    for (int i = 0; i < choreoPaths.length; i++) {
      if (hideOtherPathsOnHover &&
          hoveredPath != null &&
          hoveredPath != choreoPaths[i].name) {
        continue;
      }

      if (choreoPaths[i].trajectory.states.isEmpty) {
        continue;
      }

      _paintTrajectory(
          choreoPaths[i].trajectory,
          canvas,
          (hoveredPath == choreoPaths[i].name)
              ? Colors.orange
              : colorScheme.secondary);
      _paintChoreoWaypoint(
          choreoPaths[i].trajectory.states.first, canvas, Colors.green, scale);
      _paintChoreoWaypoint(
          choreoPaths[i].trajectory.states.last, canvas, Colors.red, scale);
      _paintChoreoMarkers(choreoPaths[i], canvas);
    }

    if (optimizedPath != null) {
      _paintPathPoints(optimizedPath!, canvas, Colors.deepPurpleAccent, 4.0);
    }

    for (int i = 1; i < paths.length; i++) {
      // Paint warnings between breaks in paths
      Translation2d prevPathEnd = paths[i - 1].pathPoints.last.position;
      Translation2d pathStart = paths[i].pathPoints.first.position;

      if (prevPathEnd.getDistance(pathStart) >= 0.25) {
        _paintBreakWarning(prevPathEnd, pathStart, canvas, scale);
      }
    }

    for (int i = 1; i < choreoPaths.length; i++) {
      // Paint warnings between breaks in paths
      Translation2d prevPathEnd =
          choreoPaths[i - 1].trajectory.states.last.pose.translation;
      Translation2d pathStart =
          choreoPaths[i].trajectory.states.first.pose.translation;

      if (prevPathEnd.getDistance(pathStart) >= 0.25) {
        _paintBreakWarning(prevPathEnd, pathStart, canvas, scale);
      }
    }

    if (prefs.getBool(PrefsKeys.showStates) ?? Defaults.showStates) {
      _paintTrajectoryStates(simulatedPath, canvas);
    }

    if (previewTime != null) {
      TrajectoryState state = simulatedPath!.sample(previewTime!.value);
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
            modPoses, fieldImage, scale, canvas, colorScheme.primary);
      }

      PathPainterUtil.paintRobotOutline(
          Pose2d(state.pose.translation, rotation),
          fieldImage,
          robotSize,
          scale,
          canvas,
          colorScheme.primary,
          showDetails: prefs.getBool(PrefsKeys.showRobotDetails) ??
              Defaults.showRobotDetails,
          colorScheme.surfaceContainer);
    }
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) {
    return true; // This will just be repainted all the time anyways from the animation
  }

  void _paintTrajectoryStates(PathPlannerTrajectory? traj, Canvas canvas) {
    if (traj == null) {
      return;
    }

    var paint = Paint()..style = PaintingStyle.fill;

    num maxVel = 0.0;
    for (TrajectoryState s in traj.states) {
      maxVel = max(
          maxVel, sqrt(pow(s.fieldSpeeds.vx, 2) + pow(s.fieldSpeeds.vy, 2)));
    }

    for (TrajectoryState s in traj.states) {
      num normalizedVel =
          sqrt(pow(s.fieldSpeeds.vx, 2) + pow(s.fieldSpeeds.vy, 2)) / maxVel;
      normalizedVel = normalizedVel.clamp(0.0, 1.0);

      if (normalizedVel <= 0.33) {
        // Lerp between red and orange
        paint.color =
            Color.lerp(Colors.red, Colors.orange, normalizedVel / 0.33)!;
      } else if (normalizedVel <= 0.67) {
        // Lerp between orange and yellow
        paint.color = Color.lerp(
            Colors.orange, Colors.yellow, (normalizedVel - 0.33) / 0.34)!;
      } else {
        // Lerp between yellow and green
        paint.color = Color.lerp(
            Colors.yellow, Colors.green, (normalizedVel - 0.67) / 0.33)!;
      }
      Offset pos = PathPainterUtil.pointToPixelOffset(
          s.pose.translation, scale, fieldImage);
      canvas.drawCircle(pos, 3.0, paint);
    }
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

  void _paintChoreoWaypoint(
      TrajectoryState state, Canvas canvas, Color color, double scale) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(
            state.pose.translation, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = colorScheme.surfaceContainer;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(
            state.pose.translation, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);

    // Draw robot
    PathPainterUtil.paintRobotOutline(state.pose, fieldImage, robotSize, scale,
        canvas, color.withOpacity(0.5), colorScheme.surfaceContainer);
  }

  void _paintPathPoints(PathPlannerPath path, Canvas canvas, Color baseColor,
      [double strokeWidth = 2.0]) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = strokeWidth;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        path.pathPoints[0].position, scale, fieldImage);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < path.pathPoints.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[i].position, scale, fieldImage);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);

    if (selectedZone != null) {
      paint.color = Colors.orange;
      paint.strokeWidth = 6;
      p.reset();

      num startPos = path.constraintZones[selectedZone!].minWaypointRelativePos;
      num endPos = path.constraintZones[selectedZone!].maxWaypointRelativePos;

      Offset start = PathPainterUtil.pointToPixelOffset(
          path.samplePath(startPos), scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (num t = startPos + 0.05; t <= endPos; t += 0.05) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.samplePath(t), scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }
      Offset end = PathPainterUtil.pointToPixelOffset(
          path.samplePath(endPos), scale, fieldImage);
      p.lineTo(end.dx, end.dy);

      canvas.drawPath(p, paint);
    }

    if (hoveredZone != null && selectedZone != hoveredZone) {
      paint.color = Colors.deepPurpleAccent;
      paint.strokeWidth = 6;
      p.reset();

      num startPos = path.constraintZones[hoveredZone!].minWaypointRelativePos;
      num endPos = path.constraintZones[hoveredZone!].maxWaypointRelativePos;

      Offset start = PathPainterUtil.pointToPixelOffset(
          path.samplePath(startPos), scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (num t = startPos + 0.05; t <= endPos; t += 0.05) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.samplePath(t), scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }
      Offset end = PathPainterUtil.pointToPixelOffset(
          path.samplePath(endPos), scale, fieldImage);
      p.lineTo(end.dx, end.dy);

      canvas.drawPath(p, paint);
    }

    if (selectedPointZone != null) {
      paint.color = Colors.orange;
      paint.strokeWidth = 6;
      p.reset();

      num startPos =
          path.pointTowardsZones[selectedPointZone!].minWaypointRelativePos;
      num endPos =
          path.pointTowardsZones[selectedPointZone!].maxWaypointRelativePos;

      Offset start = PathPainterUtil.pointToPixelOffset(
          path.samplePath(startPos), scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (num t = startPos + 0.05; t <= endPos; t += 0.05) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.samplePath(t), scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }

      Offset end = PathPainterUtil.pointToPixelOffset(
          path.samplePath(endPos), scale, fieldImage);
      p.lineTo(end.dx, end.dy);

      canvas.drawPath(p, paint);
    }

    if (hoveredPointZone != null && selectedPointZone != hoveredPointZone) {
      paint.color = Colors.deepPurpleAccent;
      paint.strokeWidth = 6;
      p.reset();

      num startPos =
          path.pointTowardsZones[hoveredPointZone!].minWaypointRelativePos;
      num endPos =
          path.pointTowardsZones[hoveredPointZone!].maxWaypointRelativePos;

      Offset start = PathPainterUtil.pointToPixelOffset(
          path.samplePath(startPos), scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (num t = startPos + 0.05; t <= endPos; t += 0.05) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.samplePath(t), scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }

      Offset end = PathPainterUtil.pointToPixelOffset(
          path.samplePath(endPos), scale, fieldImage);
      p.lineTo(end.dx, end.dy);

      canvas.drawPath(p, paint);
    }

    if (selectedMarker != null && path.eventMarkers[selectedMarker!].isZoned) {
      paint.color = Colors.orange;
      paint.strokeWidth = 6;
      p.reset();

      num startPos = path.eventMarkers[selectedMarker!].waypointRelativePos;
      num endPos = path.eventMarkers[selectedMarker!].endWaypointRelativePos!;

      Offset start = PathPainterUtil.pointToPixelOffset(
          path.samplePath(startPos), scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (num t = startPos + 0.05; t <= endPos; t += 0.05) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.samplePath(t), scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }
      Offset end = PathPainterUtil.pointToPixelOffset(
          path.samplePath(endPos), scale, fieldImage);
      p.lineTo(end.dx, end.dy);

      canvas.drawPath(p, paint);
    }

    if (hoveredMarker != null &&
        hoveredMarker != selectedMarker &&
        path.eventMarkers[hoveredMarker!].isZoned) {
      paint.color = Colors.deepPurpleAccent;
      paint.strokeWidth = 6;
      p.reset();

      num startPos = path.eventMarkers[hoveredMarker!].waypointRelativePos;
      num endPos = path.eventMarkers[hoveredMarker!].endWaypointRelativePos!;

      Offset start = PathPainterUtil.pointToPixelOffset(
          path.samplePath(startPos), scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (num t = startPos + 0.05; t <= endPos; t += 0.05) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.samplePath(t), scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }
      Offset end = PathPainterUtil.pointToPixelOffset(
          path.samplePath(endPos), scale, fieldImage);
      p.lineTo(end.dx, end.dy);

      canvas.drawPath(p, paint);
    }
  }

  void _paintMarkers(PathPlannerPath path, Canvas canvas) {
    for (int i = 0; i < path.eventMarkers.length; i++) {
      var position = path.samplePath(path.eventMarkers[i].waypointRelativePos);

      Color markerColor = Colors.grey[700]!;
      Color markerStrokeColor = colorScheme.surfaceContainer;
      if (selectedMarker == i) {
        markerColor = Colors.orange;
      } else if (hoveredMarker == i) {
        markerColor = Colors.deepPurpleAccent;
      }

      Offset markerPos =
          PathPainterUtil.pointToPixelOffset(position, scale, fieldImage);

      PathPainterUtil.paintMarker(
          canvas, markerPos, markerColor, markerStrokeColor);
    }
  }

  void _paintChoreoMarkers(ChoreoPath path, Canvas canvas) {
    for (num timestamp in path.eventMarkerTimes) {
      TrajectoryState s = path.trajectory.sample(timestamp);
      Offset markerPos = PathPainterUtil.pointToPixelOffset(
          s.pose.translation, scale, fieldImage);

      PathPainterUtil.paintMarker(
          canvas, markerPos, Colors.grey[700]!, colorScheme.onSurface);
    }
  }

  void _paintPointZonePositions(
      PathPlannerPath path, Canvas canvas, double scale) {
    if (selectedPointZone != null) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.orange
        ..strokeWidth = 3;

      PointTowardsZone z = path.pointTowardsZones[selectedPointZone!];
      final location = PathPainterUtil.pointToPixelOffset(
          z.fieldPosition, scale, fieldImage);

      canvas.drawCircle(location,
          PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage), paint);

      paint.style = PaintingStyle.stroke;
      canvas.drawCircle(location,
          PathPainterUtil.uiPointSizeToPixels(40, scale, fieldImage), paint);
    }

    if (hoveredPointZone != null && hoveredPointZone != selectedPointZone) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.deepPurpleAccent
        ..strokeWidth = 3;

      PointTowardsZone z = path.pointTowardsZones[hoveredPointZone!];
      final location = PathPainterUtil.pointToPixelOffset(
          z.fieldPosition, scale, fieldImage);

      canvas.drawCircle(location,
          PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage), paint);

      paint.style = PaintingStyle.stroke;
      canvas.drawCircle(location,
          PathPainterUtil.uiPointSizeToPixels(40, scale, fieldImage), paint);
    }
  }

  void _paintRotations(PathPlannerPath path, Canvas canvas, double scale) {
    for (int i = 0; i < path.pathPoints.length - 1; i++) {
      if (path.pathPoints[i].rotationTarget != null &&
          path.pathPoints[i].rotationTarget!.displayInEditor) {
        RotationTarget target = path.pathPoints[i].rotationTarget!;
        Color rotationColor = Colors.grey[700]!;
        if (selectedRotTarget != null &&
            path.rotationTargets[selectedRotTarget!] == target) {
          rotationColor = Colors.orange;
        } else if (hoveredRotTarget != null &&
            path.rotationTargets[hoveredRotTarget!] == target) {
          rotationColor = Colors.deepPurpleAccent;
        }

        PathPainterUtil.paintRobotOutline(
            Pose2d(path.pathPoints[i].position, target.rotation),
            fieldImage,
            robotSize,
            scale,
            canvas,
            rotationColor,
            colorScheme.surfaceContainer);
      }
    }

    PathPainterUtil.paintRobotOutline(
        Pose2d(path.waypoints.first.anchor, path.idealStartingState.rotation),
        fieldImage,
        robotSize,
        scale,
        canvas,
        Colors.green.withOpacity(0.5),
        colorScheme.surfaceContainer);

    PathPainterUtil.paintRobotOutline(
        Pose2d(path.waypoints[path.waypoints.length - 1].anchor,
            path.goalEndState.rotation),
        fieldImage,
        robotSize,
        scale,
        canvas,
        Colors.red.withOpacity(0.5),
        colorScheme.surfaceContainer);
  }

  void _paintBreakWarning(Translation2d prevPathEnd, Translation2d pathStart,
      Canvas canvas, double scale) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.yellow[800]!
      ..strokeWidth = 3;

    final p1 =
        PathPainterUtil.pointToPixelOffset(prevPathEnd, scale, fieldImage);
    final p2 = PathPainterUtil.pointToPixelOffset(pathStart, scale, fieldImage);
    final distance = (p2 - p1).distance;
    final normalizedPattern = [7, 5].map((width) => width / distance).toList();
    final points = <Offset>[];
    double t = 0.0;
    int i = 0;
    while (t < 1.0) {
      points.add(Offset.lerp(p1, p2, t)!);
      t += normalizedPattern[i++];
      points.add(Offset.lerp(p1, p2, t.clamp(0.0, 1.0))!);
      t += normalizedPattern[i++];
      i %= normalizedPattern.length;
    }
    canvas.drawPoints(PointMode.lines, points, paint);

    Offset middle = Offset.lerp(p1, p2, 0.5)!;

    const IconData warningIcon = Icons.warning_rounded;

    TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(warningIcon.codePoint),
        style: TextStyle(
          fontSize: 40,
          color: Colors.yellow[700]!,
          fontFamily: warningIcon.fontFamily,
        ),
      ),
    );

    TextPainter textStrokePainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(warningIcon.codePoint),
        style: TextStyle(
          fontSize: 40,
          fontFamily: warningIcon.fontFamily,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = colorScheme.surfaceContainer,
        ),
      ),
    );

    textPainter.layout();
    textStrokePainter.layout();

    textPainter.paint(canvas, middle - const Offset(20, 25));
    textStrokePainter.paint(canvas, middle - const Offset(20, 25));
  }

  void _paintRadius(PathPlannerPath path, Canvas canvas, double scale) {
    if (selectedWaypoint != null) {
      var paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = colorScheme.surfaceContainerHighest
        ..strokeWidth = 2;

      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              path.waypoints[selectedWaypoint!].anchor, scale, fieldImage),
          PathPainterUtil.metersToPixels(
              robotRadius.toDouble(), scale, fieldImage),
          paint);
    }
  }

  void _paintWaypoint(
      PathPlannerPath path, Canvas canvas, double scale, int waypointIdx) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (waypointIdx == selectedWaypoint) {
      paint.color = Colors.orange;
    } else if (waypointIdx == hoveredWaypoint) {
      paint.color = Colors.deepPurpleAccent;
    } else {
      paint.color = Colors.grey[700]!;
    }

    Waypoint waypoint = path.waypoints[waypointIdx];

    if (!simple) {
      //draw control point lines
      if (waypoint.nextControl != null) {
        canvas.drawLine(
            PathPainterUtil.pointToPixelOffset(
                waypoint.anchor, scale, fieldImage),
            PathPainterUtil.pointToPixelOffset(
                waypoint.nextControl!, scale, fieldImage),
            paint);
      }
      if (waypoint.prevControl != null) {
        canvas.drawLine(
            PathPainterUtil.pointToPixelOffset(
                waypoint.anchor, scale, fieldImage),
            PathPainterUtil.pointToPixelOffset(
                waypoint.prevControl!, scale, fieldImage),
            paint);
      }
    }

    if (waypointIdx == 0) {
      paint.color = Colors.green;
    } else if (waypointIdx == path.waypoints.length - 1) {
      paint.color = Colors.red;
    } else {
      paint.color = colorScheme.secondary;
    }

    if (waypointIdx == selectedWaypoint) {
      paint.color = Colors.orange;
    } else if (waypointIdx == hoveredWaypoint) {
      paint.color = Colors.deepPurpleAccent;
    }

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = colorScheme.surfaceContainer;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
        paint);

    if (!simple) {
      // draw control points
      if (waypoint.nextControl != null) {
        paint.style = PaintingStyle.fill;
        if (waypointIdx == selectedWaypoint) {
          paint.color = Colors.orange;
        } else if (waypointIdx == hoveredWaypoint) {
          paint.color = Colors.deepPurpleAccent;
        } else {
          paint.color = colorScheme.secondary;
        }

        canvas.drawCircle(
            PathPainterUtil.pointToPixelOffset(
                waypoint.nextControl!, scale, fieldImage),
            PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
            paint);
        paint.style = PaintingStyle.stroke;
        paint.color = colorScheme.surfaceContainer;
        canvas.drawCircle(
            PathPainterUtil.pointToPixelOffset(
                waypoint.nextControl!, scale, fieldImage),
            PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
            paint);
      }
      if (waypoint.prevControl != null) {
        paint.style = PaintingStyle.fill;
        if (waypointIdx == selectedWaypoint) {
          paint.color = Colors.orange;
        } else if (waypointIdx == hoveredWaypoint) {
          paint.color = Colors.deepPurpleAccent;
        } else {
          paint.color = colorScheme.secondary;
        }

        canvas.drawCircle(
            PathPainterUtil.pointToPixelOffset(
                waypoint.prevControl!, scale, fieldImage),
            PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
            paint);
        paint.style = PaintingStyle.stroke;
        paint.color = colorScheme.surfaceContainer;
        canvas.drawCircle(
            PathPainterUtil.pointToPixelOffset(
                waypoint.prevControl!, scale, fieldImage),
            PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
            paint);
      }
    }
  }

  void _paintGrid(Canvas canvas, Size size, bool showGrid) {
    if (!showGrid) return;

    final paint = Paint()
      ..color = colorScheme.secondary.withOpacity(0.2) // More transparent
      ..strokeWidth = 1;

    double gridSpacing = PathPainterUtil.metersToPixels(0.5, scale, fieldImage);

    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
}
