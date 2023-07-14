import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/path/path_point.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';

class ProjectItemCard extends StatefulWidget {
  final String name;
  final FieldImage fieldImage;
  final PathPlannerPath path;

  const ProjectItemCard({
    super.key,
    required this.name,
    required this.fieldImage,
    required this.path,
  });

  @override
  State<ProjectItemCard> createState() => _ProjectItemCardState();
}

class _ProjectItemCardState extends State<ProjectItemCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              height: 38,
              color: Colors.white.withOpacity(0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tooltip(
                    message: 'Duplicate',
                    waitDuration: const Duration(seconds: 1),
                    child: FittedBox(
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.copy),
                      ),
                    ),
                  ),
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 24),
                  ),
                  Tooltip(
                    message: 'Delete',
                    waitDuration: const Duration(seconds: 1),
                    child: FittedBox(
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.delete_forever),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (event) => setState(() {
                _hovering = true;
              }),
              onExit: (event) => setState(() {
                _hovering = false;
              }),
              child: GestureDetector(
                onTap: () {
                  print('${widget.name} opened');
                },
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Stack(
                        children: [
                          widget.fieldImage.getWidget(),
                          Positioned.fill(
                            child: _PathPreviewPainter(
                              path: widget.path,
                              fieldImage: widget.fieldImage,
                            ),
                          ),
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _hovering ? 1.0 : 0.0,
                              curve: Curves.easeInOut,
                              duration: const Duration(milliseconds: 200),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                child: Container(),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: AnimatedScale(
                                scale: _hovering ? 1.0 : 0.0,
                                curve: Curves.easeInOut,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.edit,
                                  color: colorScheme.onSurface,
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathPreviewPainter extends StatelessWidget {
  final PathPlannerPath path;
  final FieldImage fieldImage;

  const _PathPreviewPainter({
    super.key,
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

  static double scale = 1;

  const _Painter({
    required this.path,
    required this.fieldImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    _paintPathPoints(
        path.pathPoints, canvas, scale, Colors.grey[300]!, fieldImage);

    _paintWaypoint(canvas, scale, 0);
    _paintWaypoint(canvas, scale, path.waypoints.length - 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }

  static void _paintPathPoints(List<PathPoint> pathPoints, Canvas canvas,
      double scale, Color baseColor, FieldImage fieldImage) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeWidth = 1.5;

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
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(35, scale, fieldImage),
        paint);
  }
}
