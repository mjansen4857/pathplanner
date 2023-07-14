import 'package:flutter/material.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';

import '../../path/waypoint.dart';

class PathPainter extends StatelessWidget {
  final PathPlannerPath path;
  final FieldImage fieldImage;
  final int? hoveredWaypoint;

  const PathPainter({
    super.key,
    required this.path,
    required this.fieldImage,
    this.hoveredWaypoint,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Painter(
        path: path,
        fieldImage: fieldImage,
        hoveredWaypoint: hoveredWaypoint,
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final PathPlannerPath path;
  final FieldImage fieldImage;
  final int? hoveredWaypoint;

  static double scale = 1;

  const _Painter({
    required this.path,
    required this.fieldImage,
    this.hoveredWaypoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    _paintPathPoints(
        path.pathPoints, canvas, scale, Colors.grey[300]!, fieldImage);

    for (int i = 0; i < path.waypoints.length; i++) {
      _paintWaypoint(canvas, scale, i);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  static void _paintPathPoints(List<PathPoint> pathPoints, Canvas canvas,
      double scale, Color baseColor, FieldImage fieldImage) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 2;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        pathPoints[0].position, scale, fieldImage);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < pathPoints.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          pathPoints[i].position, scale, fieldImage);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);
  }

  void _paintWaypoint(Canvas canvas, double scale, int waypointIdx) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color =
          (waypointIdx == hoveredWaypoint) ? Colors.orange : Colors.grey[700]!
      ..strokeWidth = 2;

    Waypoint waypoint = path.waypoints[waypointIdx];

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

    if (waypointIdx == 0) {
      paint.color = Colors.green;
    } else if (waypointIdx == path.waypoints.length - 1) {
      paint.color = Colors.red;
    } else {
      paint.color = Colors.grey[300]!;
    }

    if (waypointIdx == hoveredWaypoint) {
      paint.color = Colors.orange;
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

    // draw control points
    if (waypoint.nextControl != null) {
      paint.style = PaintingStyle.fill;
      paint.color =
          (waypointIdx == hoveredWaypoint) ? Colors.orange : Colors.grey[300]!;

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
      paint.color =
          (waypointIdx == hoveredWaypoint) ? Colors.orange : Colors.grey[300]!;

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
