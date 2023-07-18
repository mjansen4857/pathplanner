import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';

class MiniPathPreview extends StatelessWidget {
  final PathPlannerPath path;
  final FieldImage fieldImage;

  const MiniPathPreview({
    super.key,
    required this.path,
    required this.fieldImage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        fieldImage.getWidget(small: true),
        Positioned.fill(
          child: _PathPreviewPainter(
            path: path,
            fieldImage: fieldImage,
          ),
        ),
      ],
    );
  }
}

class _PathPreviewPainter extends StatelessWidget {
  final PathPlannerPath path;
  final FieldImage fieldImage;

  const _PathPreviewPainter({
    required this.path,
    required this.fieldImage,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Painter(
        path: path,
        fieldImage: fieldImage,
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final PathPlannerPath path;
  final FieldImage fieldImage;

  const _Painter({
    required this.path,
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

    _paintPathPoints(canvas, scale, Colors.grey[300]!);

    _paintWaypoint(canvas, scale, 0);
    _paintWaypoint(canvas, scale, path.waypoints.length - 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }

  void _paintPathPoints(Canvas canvas, double scale, Color baseColor) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 1.5;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        path.pathPoints[0].position, scale, fieldImage,
        small: true);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < path.pathPoints.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          path.pathPoints[i].position, scale, fieldImage,
          small: true);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);
  }

  void _paintWaypoint(Canvas canvas, double scale, int waypointIdx) {
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
