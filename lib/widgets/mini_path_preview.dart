import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/util/path_painter_util.dart';

class MiniPathsPreview extends StatelessWidget {
  final List<List<Translation2d>> paths;
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
  final List<List<Translation2d>> paths;
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
        colorScheme: Theme.of(context).colorScheme,
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final List<List<Translation2d>> paths;
  final FieldImage fieldImage;
  final ColorScheme colorScheme;

  const _Painter({
    required this.paths,
    required this.fieldImage,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / fieldImage.defaultSize.width;

    for (List<Translation2d> path in paths) {
      if (path.isNotEmpty) {
        _paintPathPoints(canvas, scale, colorScheme.secondary, path);
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

  void _paintPathPoints(Canvas canvas, double scale, Color baseColor,
      List<Translation2d> pathPoints) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 1.5;

    Path p = Path();

    Offset start =
        PathPainterUtil.pointToPixelOffset(pathPoints[0], scale, fieldImage);
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < pathPoints.length; i++) {
      Offset pos =
          PathPainterUtil.pointToPixelOffset(pathPoints[i], scale, fieldImage);

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);
  }

  void _paintWaypoint(
      Canvas canvas, double scale, Translation2d position, Color color) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1;

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(position, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(position, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage),
        paint);
  }
}
