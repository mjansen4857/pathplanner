import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/util/path_painter_util.dart';

class MiniPathsPreview extends StatelessWidget {
  final List<List<Point>> paths;
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
        fieldImage.getWidget(),
        Positioned.fill(
          child: PathPreviewPainter(
            paths: paths,
            fieldImage: fieldImage,
          ),
        ),
      ],
    );
  }
}

@visibleForTesting
class PathPreviewPainter extends StatelessWidget {
  final List<List<Point>> paths;
  final FieldImage fieldImage;

  const PathPreviewPainter({
    super.key,
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
  final List<List<Point>> paths;
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

    for (List<Point> path in paths) {
      if (path.isNotEmpty) {
        _paintPathPoints(canvas, scale, Colors.grey[300]!, path);
        _paintWaypoint(canvas, scale, path.first, Colors.green);
        _paintWaypoint(canvas, scale, path.last, Colors.red);
      }
    }
  }

  @override
  bool shouldRepaint(_Painter oldDelegate) {
    return oldDelegate.fieldImage != fieldImage ||
        !(const DeepCollectionEquality()).equals(oldDelegate.paths, paths);
  }

  void _paintPathPoints(
      Canvas canvas, double scale, Color baseColor, List<Point> pathPoints) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 1.5;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
        pathPoints[0], scale, fieldImage,
        small: true);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < pathPoints.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
          pathPoints[i], scale, fieldImage,
          small: true);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);
  }

  void _paintWaypoint(
      Canvas canvas, double scale, Point position, Color color) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1;

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(position, scale, fieldImage,
            small: true),
        PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage, small: true),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(position, scale, fieldImage,
            small: true),
        PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage, small: true),
        paint);
  }
}
