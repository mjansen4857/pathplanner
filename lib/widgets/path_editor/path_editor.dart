import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path.dart';

class PathEditor extends StatefulWidget {
  RobotPath path;

  PathEditor(this.path);

  @override
  _PathEditorState createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        child: Stack(
          children: [
            Image(image: AssetImage('images/field20.png')),
            Positioned.fill(
              child: Container(
                constraints: BoxConstraints(maxWidth: 1200, maxHeight: 600),
                child: CustomPaint(
                  painter: PathPainter(widget.path),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  var defaultSize = Size(1200, 600);
  RobotPath path;

  PathPainter(this.path);

  @override
  void paint(Canvas canvas, Size size) {
    var scale = size.width / defaultSize.width;

    paintCenterPath(canvas, scale);

    for (int i = 0; i < path.waypoints.length; i++) {
      paintWaypoint(canvas, scale, path.waypoints[i]);
    }
  }

  void paintCenterPath(Canvas canvas, double scale) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[300]
      ..strokeWidth = 2;

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      Path p = Path();
      Offset p0 = pointToPixelOffset(path.waypoints[i].anchorPoint, scale);
      Offset p1 = pointToPixelOffset(path.waypoints[i].nextControl, scale);
      Offset p2 = pointToPixelOffset(path.waypoints[i + 1].prevControl, scale);
      Offset p3 = pointToPixelOffset(path.waypoints[i + 1].anchorPoint, scale);
      p.moveTo(p0.dx, p0.dy);
      p.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

      canvas.drawPath(p, paint);
    }
  }

  void paintWaypoint(Canvas canvas, double scale, Waypoint waypoint) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 2;

    //draw control point lines
    if (waypoint.nextControl != null) {
      canvas.drawLine(pointToPixelOffset(waypoint.anchorPoint, scale),
          pointToPixelOffset(waypoint.nextControl, scale), paint);
    }
    if (waypoint.prevControl != null) {
      canvas.drawLine(pointToPixelOffset(waypoint.anchorPoint, scale),
          pointToPixelOffset(waypoint.prevControl, scale), paint);
    }

    if (waypoint.isStartPoint()) {
      paint.color = Colors.green;
    } else if (waypoint.isEndPoint()) {
      paint.color = Colors.red;
    } else {
      paint.color = Colors.grey[300];
    }

    // draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        pointToPixelOffset(waypoint.anchorPoint, scale), 8 * scale, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(
        pointToPixelOffset(waypoint.anchorPoint, scale), 8 * scale, paint);

    // draw control points
    if (waypoint.nextControl != null) {
      paint.style = PaintingStyle.fill;
      paint.color = Colors.grey[300];

      canvas.drawCircle(
          pointToPixelOffset(waypoint.nextControl, scale), 6 * scale, paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          pointToPixelOffset(waypoint.nextControl, scale), 6 * scale, paint);
    }
    if (waypoint.prevControl != null) {
      paint.style = PaintingStyle.fill;
      paint.color = Colors.grey[300];

      canvas.drawCircle(
          pointToPixelOffset(waypoint.prevControl, scale), 6 * scale, paint);
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.black;
      canvas.drawCircle(
          pointToPixelOffset(waypoint.prevControl, scale), 6 * scale, paint);
    }
  }

  Offset pointToPixelOffset(Point point, double scale) {
    return Offset((point.x * 66.11) + 76,
            defaultSize.height - ((point.y * 66.11) + 78))
        .scale(scale, scale);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
