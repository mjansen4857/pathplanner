import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/simulator/trajectory_generator.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/mini_path_preview.dart';

void main() {
  MemoryFileSystem fs = MemoryFileSystem();
  PathPlannerPath path = PathPlannerPath.defaultPath(pathDir: '/paths', fs: fs);
  ChoreoPath path2 = ChoreoPath(
    name: 'test',
    trajectory: Trajectory(states: [
      TrajectoryState(time: 0.0),
      TrajectoryState(time: 1.0),
    ]),
    fs: fs,
    choreoDir: '/choreo',
    eventMarkerTimes: [0.5],
  );

  testWidgets('mini preview w/ small image', (widgetTester) async {
    var fieldImage = FieldImage.official(OfficialField.chargedUp);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MiniPathsPreview(
          paths: [path.getPathPositions(), path2.getPathPositions()],
          fieldImage: fieldImage,
        ),
      ),
    ));

    expect(find.byType(PathPreviewPainter), findsOneWidget);
    expect(find.image(fieldImage.image.image), findsOneWidget);
  });

  testWidgets('mini preview w/o small image', (widgetTester) async {
    var fieldImage = FieldImage.official(OfficialField.rapidReact);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MiniPathsPreview(
          paths: [path.getPathPositions(), path2.getPathPositions()],
          fieldImage: fieldImage,
        ),
      ),
    ));

    expect(find.byType(PathPreviewPainter), findsOneWidget);
    expect(find.image(fieldImage.image.image), findsOneWidget);
  });
}
