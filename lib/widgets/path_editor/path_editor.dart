import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PathEditor extends StatefulWidget {
  PathEditor() : super();

  @override
  _PathEditorState createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: CustomPaint(
        painter: PathPainter(),
        child: Image(
          image: AssetImage('images/field20.png'),
        ),
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  var defaultSize = Size(1200, 600);
  @override
  void paint(Canvas canvas, Size size) {
    var scale = size.width / defaultSize.width;

    canvas.drawRect(
        Rect.fromLTRB(100 * scale, 100 * scale, 200 * scale, 200 * scale),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white
          ..strokeWidth = 5);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
