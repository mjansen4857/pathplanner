import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/services/simulator/trajectory_generator.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PathPainter extends CustomPainter {
  final List<PathPlannerPath> paths;
  final FieldImage fieldImage;
  final bool simple;
  final bool hideOtherPathsOnHover;
  final String? hoveredPath;
  final int? hoveredWaypoint;
  final int? selectedWaypoint;
  final int? hoveredZone;
  final int? selectedZone;
  final int? hoveredRotTarget;
  final int? selectedRotTarget;
  final int? hoveredMarker;
  final int? selectedMarker;
  final Pose2d? startingPose;
  final Trajectory? simulatedPath;
  final Color? previewColor;
  final SharedPreferences prefs;

  late Size robotSize;
  late num robotRadius;
  late bool holonomicMode;
  Animation<num>? previewTime;

  static double scale = 1;

  PathPainter({
    required this.paths,
    required this.fieldImage,
    this.simple = false,
    this.hideOtherPathsOnHover = false,
    this.hoveredPath,
    this.hoveredWaypoint,
    this.selectedWaypoint,
    this.hoveredZone,
    this.selectedZone,
    this.hoveredRotTarget,
    this.selectedRotTarget,
    this.hoveredMarker,
    this.selectedMarker,
    this.startingPose,
    this.simulatedPath,
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

    holonomicMode =
        prefs.getBool(PrefsKeys.holonomicMode) ?? Defaults.holonomicMode;

    if (simulatedPath != null && animation != null) {
      previewTime = Tween<num>(begin: 0, end: simulatedPath!.states.last.time)
          .animate(animation);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    for (int i = 0; i < paths.length; i++) {
      if (hideOtherPathsOnHover &&
          hoveredPath != null &&
          hoveredPath != paths[i].name) {
        continue;
      }

      if (!simple) {
        _paintRadius(paths[i], canvas, scale);
      }

      _paintPathPoints(paths[i], canvas,
          (hoveredPath == paths[i].name) ? Colors.orange : Colors.grey[300]!);

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
    }

    if (startingPose != null) {
      PathPainterUtil.paintRobotOutline(
          startingPose!.position,
          startingPose!.rotation,
          fieldImage,
          robotSize,
          scale,
          canvas,
          Colors.green.withOpacity(0.8));

      var paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.green.withOpacity(0.5)
        ..strokeWidth = 2;

      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              startingPose!.position, scale, fieldImage),
          PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
          paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              startingPose!.position, scale, fieldImage),
          PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
          paint);
    }

    if (previewTime != null) {
      TrajectoryState state = simulatedPath!.sample(previewTime!.value);
      num rotation =
          holonomicMode ? state.holonomicRotationRadians : state.headingRadians;

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
  bool shouldRepaint(PathPainter oldDelegate) {
    return true; // This will just be repainted all the time anyways from the animation
  }

  void _paintPathPoints(PathPlannerPath path, Canvas canvas, Color baseColor) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 2;

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
      paint.strokeWidth = 4;
      p.reset();

      int startIdx =
          (path.constraintZones[selectedZone!].minWaypointRelativePos /
                  pathResolution)
              .round();
      int endIdx = min(
          (path.constraintZones[selectedZone!].maxWaypointRelativePos /
                  pathResolution)
              .round(),
          path.pathPoints.length - 1);
      Offset start = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[startIdx].position, scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (int i = startIdx; i <= endIdx; i++) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.pathPoints[i].position, scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }

      canvas.drawPath(p, paint);
    }
    if (hoveredZone != null && selectedZone != hoveredZone) {
      paint.color = Colors.deepPurpleAccent;
      paint.strokeWidth = 4;
      p.reset();

      int startIdx =
          (path.constraintZones[hoveredZone!].minWaypointRelativePos /
                  pathResolution)
              .round();
      int endIdx = min(
          (path.constraintZones[hoveredZone!].maxWaypointRelativePos /
                  pathResolution)
              .round(),
          path.pathPoints.length - 1);
      Offset start = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[startIdx].position, scale, fieldImage);
      p.moveTo(start.dx, start.dy);

      for (int i = startIdx; i <= endIdx; i++) {
        Offset pos = PathPainterUtil.pointToPixelOffset(
            path.pathPoints[i].position, scale, fieldImage);

        p.lineTo(pos.dx, pos.dy);
      }

      canvas.drawPath(p, paint);
    }
  }

  void _paintMarkers(PathPlannerPath path, Canvas canvas) {
    for (int i = 0; i < path.eventMarkers.length; i++) {
      int pointIdx =
          (path.eventMarkers[i].waypointRelativePos / pathResolution).round();

      Color markerColor = Colors.grey[700]!;
      if (selectedMarker == i) {
        markerColor = Colors.orange;
      } else if (hoveredMarker == i) {
        markerColor = Colors.deepPurpleAccent;
      }

      Offset markerPos = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[pointIdx].position, scale, fieldImage);

      PathPainterUtil.paintMarker(canvas, markerPos, markerColor);
    }
  }

  void _paintRotations(PathPlannerPath path, Canvas canvas, double scale) {
    for (int i = 0; i < path.rotationTargets.length; i++) {
      int pointIdx =
          (path.rotationTargets[i].waypointRelativePos / pathResolution)
              .round();

      Color rotationColor = Colors.grey[700]!;
      if (selectedRotTarget == i) {
        rotationColor = Colors.orange;
      } else if (hoveredRotTarget == i) {
        rotationColor = Colors.deepPurpleAccent;
      }

      PathPainterUtil.paintRobotOutline(
          path.pathPoints[pointIdx].position,
          path.rotationTargets[i].rotationDegrees,
          fieldImage,
          robotSize,
          scale,
          canvas,
          rotationColor);
    }

    PathPainterUtil.paintRobotOutline(
        path.waypoints[path.waypoints.length - 1].anchor,
        path.goalEndState.rotation,
        fieldImage,
        robotSize,
        scale,
        canvas,
        Colors.red.withOpacity(0.5));
  }

  void _paintRadius(PathPlannerPath path, Canvas canvas, double scale) {
    if (selectedWaypoint != null) {
      var paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.grey[800]!
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
      paint.color = Colors.grey[300]!;
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
    paint.color = Colors.black;
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
          paint.color = Colors.grey[300]!;
        }

        canvas.drawCircle(
            PathPainterUtil.pointToPixelOffset(
                waypoint.nextControl!, scale, fieldImage),
            PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
            paint);
        paint.style = PaintingStyle.stroke;
        paint.color = Colors.black;
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
          paint.color = Colors.grey[300]!;
        }

        canvas.drawCircle(
            PathPainterUtil.pointToPixelOffset(
                waypoint.prevControl!, scale, fieldImage),
            PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
            paint);
        paint.style = PaintingStyle.stroke;
        paint.color = Colors.black;
        canvas.drawCircle(
            PathPainterUtil.pointToPixelOffset(
                waypoint.prevControl!, scale, fieldImage),
            PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
            paint);
      }
    }
  }
}
