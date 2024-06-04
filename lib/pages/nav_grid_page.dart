import 'dart:convert';
import 'dart:math';

import 'package:file/file.dart';
import 'package:flutter/material.dart';
// import 'package:function_tree/function_tree.dart';
import 'package:path/path.dart';
import 'package:pathplanner/pathfinding/nav_grid.dart';
import 'package:pathplanner/widgets/dialogs/nav_grid_edit_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/util/path_painter_util.dart';

class NavGridPage extends StatefulWidget {
  final Directory deployDirectory;
  final FieldImage fieldImage;
  final FileSystem fs;

  const NavGridPage({
    super.key,
    required this.deployDirectory,
    required this.fs,
    required this.fieldImage,
  });

  @override
  State<NavGridPage> createState() => _NavGridPageState();
}

class _NavGridPageState extends State<NavGridPage> {
  bool _loading = true;
  bool _adding = true;
  late NavGrid _grid;

  @override
  void initState() {
    super.initState();

    File gridFile =
        widget.fs.file(join(widget.deployDirectory.path, 'navgrid.json'));
    gridFile.exists().then((value) async {
      if (value) {
        String fileContent = gridFile.readAsStringSync();
        Map<String, dynamic> json = jsonDecode(fileContent);
        setState(() {
          _grid = NavGrid.fromJson(json);
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
              onTapUp: (details) {
                double x = _xPixelsToMeters(details.localPosition.dx);
                double y = _yPixelsToMeters(details.localPosition.dy);

                int row = (y / _grid.nodeSizeMeters).floor();
                int col = (x / _grid.nodeSizeMeters).floor();

                if (row >= 0 &&
                    row < _grid.grid.length &&
                    col >= 0 &&
                    col < _grid.grid[row].length) {
                  setState(() {
                    _grid.grid[row][col] = !_grid.grid[row][col];
                  });

                  _saveNavGrid();
                }
              },
              onPanStart: (details) {
                double x = _xPixelsToMeters(details.localPosition.dx);
                double y = _yPixelsToMeters(details.localPosition.dy);

                int row = (y / _grid.nodeSizeMeters).floor();
                int col = (x / _grid.nodeSizeMeters).floor();

                if (row >= 0 &&
                    row < _grid.grid.length &&
                    col >= 0 &&
                    col < _grid.grid[row].length) {
                  _adding = !_grid.grid[row][col];
                }
              },
              onPanUpdate: (details) {
                double x = _xPixelsToMeters(details.localPosition.dx);
                double y = _yPixelsToMeters(details.localPosition.dy);

                int row = (y / _grid.nodeSizeMeters).floor();
                int col = (x / _grid.nodeSizeMeters).floor();

                if (row >= 0 &&
                    row < _grid.grid.length &&
                    col >= 0 &&
                    col < _grid.grid[row].length) {
                  setState(() {
                    _grid.grid[row][col] = _adding;
                  });
                }
              },
              onPanEnd: (_) {
                _saveNavGrid();
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
                          grid: _grid.grid,
                          nodeSizeMeters: _grid.nodeSizeMeters,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton.extended(
              label: const Text('Edit Grid'),
              icon: const Icon(Icons.edit),
              onPressed: _showEditDialog,
            ),
          ),
        ),
      ],
    );
  }

  void _handleGridChange(NavGrid newGrid) {
    setState(() {
      _grid = newGrid;
    });
    _saveNavGrid();
  }

  void _showEditDialog() {
    showDialog(
        context: this.context,
        builder: (context) =>
            NavGridEditDialog(grid: _grid, onGridChange: _handleGridChange));
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

  void _saveNavGrid() {
    widget.fs
        .file(join(widget.deployDirectory.path, 'navgrid.json'))
        .writeAsString(jsonEncode(_grid));
  }
}

class _NavigationPainter extends CustomPainter {
  final FieldImage fieldImage;

  final num nodeSizeMeters;
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
