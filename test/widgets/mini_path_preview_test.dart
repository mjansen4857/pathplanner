import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/mini_path_preview.dart';

void main() {
  PathPlannerPath path =
      PathPlannerPath.defaultPath(pathDir: '/paths', fs: MemoryFileSystem());

  testWidgets('mini preview w/ small image', (widgetTester) async {
    var fieldImage = FieldImage.official(OfficialField.chargedUp);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MiniPathsPreview(
          paths: [path],
          fieldImage: fieldImage,
        ),
      ),
    ));

    expect(find.byType(PathPreviewPainter), findsOneWidget);
    expect(find.image(fieldImage.imageSmall!.image), findsOneWidget);
  });

  testWidgets('mini preview w/o small image', (widgetTester) async {
    var fieldImage = FieldImage.official(OfficialField.rapidReact);

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MiniPathsPreview(
          paths: [path],
          fieldImage: fieldImage,
        ),
      ),
    ));

    expect(find.byType(PathPreviewPainter), findsOneWidget);
    expect(find.image(fieldImage.image.image), findsOneWidget);
  });
}
