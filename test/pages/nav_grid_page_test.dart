import 'dart:convert';
import 'dart:ui';

import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/pages/nav_grid_page.dart';
import 'package:pathplanner/pathfinding/nav_grid.dart';
import 'package:pathplanner/widgets/field_image.dart';

void main() {
  testWidgets('loading when no file', (widgetTester) async {
    var fs = MemoryFileSystem();
    fs.directory('/deploy').createSync(recursive: true);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NavGridPage(
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
        ),
      ),
    ));
    await widgetTester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('navgrid editor shows when file', (widgetTester) async {
    var fs = MemoryFileSystem();
    fs.directory('/deploy').createSync(recursive: true);
    NavGrid grid = NavGrid(
        fieldSize: const Size(16.54, 8.02),
        nodeSizeMeters: 0.2,
        grid: List.generate((8.02 / 0.2).ceil(),
            (index) => List.filled((16.54 / 0.2).ceil(), false)));
    fs.file('/deploy/navgrid.json').writeAsStringSync(jsonEncode(grid));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NavGridPage(
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
        ),
      ),
    ));
    await widgetTester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.image(FieldImage.defaultField.image.image), findsOneWidget);
  });

  testWidgets('navgrid editor tap', (widgetTester) async {
    var fs = MemoryFileSystem();
    fs.directory('/deploy').createSync(recursive: true);
    NavGrid grid = NavGrid(
        fieldSize: const Size(16.54, 8.02),
        nodeSizeMeters: 0.2,
        grid: List.generate((8.02 / 0.2).ceil(),
            (index) => List.filled((16.54 / 0.2).ceil(), false)));
    fs.file('/deploy/navgrid.json').writeAsStringSync(jsonEncode(grid));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NavGridPage(
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
        ),
      ),
    ));
    await widgetTester.pump();

    await widgetTester.tapAt(const Offset(200, 200));
    await widgetTester.pump();

    NavGrid editedGrid = NavGrid.fromJson(
        jsonDecode(fs.file('/deploy/navgrid.json').readAsStringSync()));
    expect(editedGrid, isNot(grid));
  });

  testWidgets('navgrid editor drag', (widgetTester) async {
    var fs = MemoryFileSystem();
    fs.directory('/deploy').createSync(recursive: true);
    NavGrid grid = NavGrid(
        fieldSize: const Size(16.54, 8.02),
        nodeSizeMeters: 0.2,
        grid: List.generate((8.02 / 0.2).ceil(),
            (index) => List.filled((16.54 / 0.2).ceil(), false)));
    fs.file('/deploy/navgrid.json').writeAsStringSync(jsonEncode(grid));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NavGridPage(
          deployDirectory: fs.directory('/deploy'),
          fs: fs,
        ),
      ),
    ));
    await widgetTester.pump();

    var gesture = await widgetTester.startGesture(const Offset(200, 200),
        kind: PointerDeviceKind.mouse);
    addTearDown(() => gesture.removePointer());
    await widgetTester.pump();
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await widgetTester.pump();
    }
    await gesture.up();
    await widgetTester.pump();

    NavGrid editedGrid = NavGrid.fromJson(
        jsonDecode(fs.file('/deploy/navgrid.json').readAsStringSync()));
    expect(editedGrid, isNot(grid));
  });
}
