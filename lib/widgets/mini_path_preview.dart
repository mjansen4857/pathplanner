import 'package:flutter/material.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';

class MiniPathsPreview extends StatelessWidget {
  final List<PathPlannerPath> paths;
  final FieldImage fieldImage;

  const MiniPathsPreview({
    super.key,
    required this.paths,
    required this.fieldImage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        fieldImage.getWidget(small: true),
        Positioned.fill(
          child: _PathPreviewPainter(
            paths: paths,
            fieldImage: fieldImage,
          ),
        ),
      ],
    );
  }
}

class _PathPreviewPainter extends StatelessWidget {
  final List<PathPlannerPath> paths;
  final FieldImage fieldImage;

  const _PathPreviewPainter({
    required this.paths,
    required this.fieldImage,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Painter(
        paths: paths,
        fieldImage: fieldImage,
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final List<PathPlannerPath> paths;
  final FieldImage fieldImage;

  const _Painter({
    required this.paths,
    required this.fieldImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double scale;

    if (fieldImage.defaultSizeSmall != null) {
      scale = size.width / fieldImage.defaultSizeSmall!.width;
    } else {
      scale = size.width / fieldImage.defaultSize.width;
    }

    for (PathPlannerPath path in paths) {
      _paintPathPoints(canvas, scale, Colors.grey[300]!, path.pathPoints);

      _paintWaypoint(canvas, scale, path, 0);
      _paintWaypoint(canvas, scale, path, path.waypoints.length - 1);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }

  void _paintPathPoints(Canvas canvas, double scale, Color baseColor,
      List<PathPoint> pathPoints) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 1.5;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        pathPoints[0].position, scale, fieldImage,
        small: true);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < pathPoints.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          pathPoints[i].position, scale, fieldImage,
          small: true);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);
  }

  void _paintWaypoint(
      Canvas canvas, double scale, PathPlannerPath path, int waypointIdx) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 1;

    Waypoint waypoint = path.waypoints[waypointIdx];

    if (waypointIdx == 0) {
      paint.color = Colors.green;
    } else if (waypointIdx == path.waypoints.length - 1) {
      paint.color = Colors.red;
    } else {
      paint.color = Colors.grey[300]!;
    }

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage,
            small: true),
        PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage, small: true),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage,
            small: true),
        PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage, small: true),
        paint);
  }
}
