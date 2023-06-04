import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/path_painter_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationEditor extends StatefulWidget {
  final FieldImage fieldImage;
  final SharedPreferences prefs;
  final Function(List<List<bool>> grid, double nodeSizeMeters) saveNavGrid;
  final Future<(List<List<bool>>, double)?> Function() loadNavGrid;

  const NavigationEditor({
    super.key,
    required this.fieldImage,
    required this.prefs,
    required this.saveNavGrid,
    required this.loadNavGrid,
  });

  @override
  State<NavigationEditor> createState() => _NavigationEditorState();
}

class _NavigationEditorState extends State<NavigationEditor> {
  final GlobalKey _key = GlobalKey();
  double _nodeSizeMeters = 0.25;
  List<List<bool>> _grid = [];

  bool _adding = true;

  @override
  void initState() {
    super.initState();

    widget.loadNavGrid().then((value) {
      if (value == null) {
        setState(() {
          _nodeSizeMeters = 0.2;
          int rows = (widget.fieldImage.defaultSize.height /
                  widget.fieldImage.pixelsPerMeter /
                  _nodeSizeMeters)
              .ceil();
          int cols = (widget.fieldImage.defaultSize.width /
                  widget.fieldImage.pixelsPerMeter /
                  _nodeSizeMeters)
              .ceil();

          for (int row = 0; row < rows; row++) {
            _grid.add(List.filled(cols, false));
          }
        });
      } else {
        var (grid, nodeSizeMeters) = value;
        setState(() {
          _grid = grid;
          _nodeSizeMeters = nodeSizeMeters;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
              onTapUp: (details) {
                double x = _xPixelsToMeters(details.localPosition.dx);
                double y = _yPixelsToMeters(details.localPosition.dy);

                int row = (y / _nodeSizeMeters).floor();
                int col = (x / _nodeSizeMeters).floor();

                if (row >= 0 &&
                    row < _grid.length &&
                    col >= 0 &&
                    col < _grid[row].length) {
                  setState(() {
                    _grid[row][col] = !_grid[row][col];
                  });

                  widget.saveNavGrid(_grid, _nodeSizeMeters);
                }
              },
              onPanStart: (details) {
                double x = _xPixelsToMeters(details.localPosition.dx);
                double y = _yPixelsToMeters(details.localPosition.dy);

                int row = (y / _nodeSizeMeters).floor();
                int col = (x / _nodeSizeMeters).floor();

                if (row >= 0 &&
                    row < _grid.length &&
                    col >= 0 &&
                    col < _grid[row].length) {
                  _adding = !_grid[row][col];
                }
              },
              onPanUpdate: (details) {
                double x = _xPixelsToMeters(details.localPosition.dx);
                double y = _yPixelsToMeters(details.localPosition.dy);

                int row = (y / _nodeSizeMeters).floor();
                int col = (x / _nodeSizeMeters).floor();

                if (row >= 0 &&
                    row < _grid.length &&
                    col >= 0 &&
                    col < _grid[row].length) {
                  setState(() {
                    _grid[row][col] = _adding;
                  });
                }
              },
              onPanEnd: (_) {
                widget.saveNavGrid(_grid, _nodeSizeMeters);
              },
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Stack(
                  children: [
                    widget.fieldImage.getWidget(),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _NavigationPainter(
                          fieldImage: widget.fieldImage,
                          grid: _grid,
                          nodeSizeMeters: _nodeSizeMeters,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels - 48) / _NavigationPainter.scale) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _yPixelsToMeters(double pixels) {
    return (widget.fieldImage.defaultSize.height -
            ((pixels - 48) / _NavigationPainter.scale)) /
        widget.fieldImage.pixelsPerMeter;
  }
}

class _NavigationPainter extends CustomPainter {
  final FieldImage fieldImage;

  final double nodeSizeMeters;
  final List<List<bool>> grid;

  static double scale = 1;

  _NavigationPainter({
    required this.fieldImage,
    required this.grid,
    required this.nodeSizeMeters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    var outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[600]!
      ..strokeWidth = 1;
    var fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red.withOpacity(0.4);

    for (int row = 0; row < grid.length; row++) {
      for (int col = 0; col < grid[row].length; col++) {
        Offset tl = PathPainterUtil.pointToPixelOffset(
            Point(col * nodeSizeMeters, row * nodeSizeMeters),
            scale,
            fieldImage);
        Offset br = PathPainterUtil.pointToPixelOffset(
            Point((col + 1) * nodeSizeMeters, (row + 1) * nodeSizeMeters),
            scale,
            fieldImage);

        if (grid[row][col]) {
          canvas.drawRect(Rect.fromPoints(tl, br), fillPaint);
        }
        canvas.drawRect(Rect.fromPoints(tl, br), outlinePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
