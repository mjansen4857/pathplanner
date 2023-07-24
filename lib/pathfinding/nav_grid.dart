import 'dart:ui';

import 'package:pathplanner/widgets/field_image.dart';

class NavGrid {
  Size fieldSize;
  num nodeSizeMeters;
  List<List<bool>> grid;

  NavGrid({
    required this.fieldSize,
    required this.nodeSizeMeters,
    required this.grid,
  });

  NavGrid.fromJson(Map<String, dynamic> json)
      : fieldSize = sizeFromJson(json['field_size']) ??
            FieldImage.defaultField.getFieldSizeMeters(),
        nodeSizeMeters = json['nodeSizeMeters'] ?? 0.2,
        grid = [] {
    grid = [
      for (var dynList in json['grid'] ?? [])
        (dynList as List<dynamic>).map((e) => e as bool).toList(),
    ];

    int rows = (fieldSize.height / nodeSizeMeters).ceil();
    int cols = (fieldSize.width / nodeSizeMeters).ceil();

    if (grid.isEmpty ||
        grid.length != rows ||
        grid[0].isEmpty ||
        grid[0].length != cols) {
      // Grid does not match what it should, replace it with an emptry grid
      grid = List.generate(rows, (index) => List.filled(cols, false));
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'field_size': {
        'x': fieldSize.width,
        'y': fieldSize.height,
      },
      'nodeSizeMeters': nodeSizeMeters,
      'grid': grid,
    };
  }

  static Size? sizeFromJson(Map<String, dynamic> sizeJson) {
    if (sizeJson['x'] == null || sizeJson['y'] == null) {
      return null;
    }
    return Size(
        (sizeJson['x'] as num).toDouble(), (sizeJson['y'] as num).toDouble());
  }
}
