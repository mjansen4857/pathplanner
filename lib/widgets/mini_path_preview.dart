import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/util/path_painter_util.dart';

class MiniPathsPreview extends StatelessWidget {
  final List<List<Translation2d>> paths;
  final List<Translation2d>? startPoints;
  final List<Translation2d>? endPoints;
  final FieldImage fieldImage;

  const MiniPathsPreview({
    super.key,
    required this.paths,
    this.startPoints,
    this.endPoints,
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
            startPoints: startPoints,
            endPoints: endPoints,
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
  final List<Translation2d>? startPoints;
  final List<Translation2d>? endPoints;
  final FieldImage fieldImage;

  const PathPreviewPainter({
    super.key,
    required this.paths,
    this.startPoints,
    this.endPoints,
    required this.fieldImage,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Painter(
        paths: paths,
        startPoints: startPoints,
        endPoints: endPoints,
        fieldImage: fieldImage,
        colorScheme: Theme.of(context).colorScheme,
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final List<List<Translation2d>> paths;
  final List<Translation2d>? startPoints;
  final List<Translation2d>? endPoints;
  final FieldImage fieldImage;
  final ColorScheme colorScheme;

  const _Painter({
    required this.paths,
    this.startPoints,
    this.endPoints,
    required this.fieldImage,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / fieldImage.defaultSize.width;

    for (List<Translation2d> path in paths) {
      if (path.isNotEmpty) {
        _paintPathPoints(canvas, scale, colorScheme.secondary, path);
      }
    }

    final starts =
        startPoints ??
        [
          for (final path in paths)
            if (path.isNotEmpty) path.first,
        ];
    final ends =
        endPoints ??
        [
          for (final path in paths)
            if (path.isNotEmpty) path.last,
        ];
    for (final start in starts) {
      _paintWaypoint(canvas, scale, start, Colors.green);
    }
    for (final end in ends) {
      _paintWaypoint(canvas, scale, end, Colors.red);
    }
  }

  @override
  bool shouldRepaint(_Painter oldDelegate) {
    return oldDelegate.fieldImage != fieldImage ||
        !(const DeepCollectionEquality()).equals(oldDelegate.paths, paths) ||
        !(const DeepCollectionEquality()).equals(
          oldDelegate.startPoints,
          startPoints,
        ) ||
        !(const DeepCollectionEquality()).equals(
          oldDelegate.endPoints,
          endPoints,
        );
  }

  void _paintPathPoints(
    Canvas canvas,
    double scale,
    Color baseColor,
    List<Translation2d> pathPoints,
  ) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 1.5;

    Path p = Path();

    Offset start = PathPainterUtil.pointToPixelOffset(
      pathPoints[0],
      scale,
      fieldImage,
    );
    p.moveTo(start.dx, start.dy);

    for (int i = 1; i < pathPoints.length; i++) {
      Offset pos = PathPainterUtil.pointToPixelOffset(
        pathPoints[i],
        scale,
        fieldImage,
      );

      p.lineTo(pos.dx, pos.dy);
    }

    canvas.drawPath(p, paint);
  }

  void _paintWaypoint(
    Canvas canvas,
    double scale,
    Translation2d position,
    Color color,
  ) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1;

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
      PathPainterUtil.pointToPixelOffset(position, scale, fieldImage),
      PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage),
      paint,
    );
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
      PathPainterUtil.pointToPixelOffset(position, scale, fieldImage),
      PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage),
      paint,
    );
  }
}
