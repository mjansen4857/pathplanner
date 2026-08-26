import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/pathplanner_auto.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/path2_painter.dart';
import 'package:pathplanner/widgets/editor/preview_seekbar.dart';
import 'package:pathplanner/widgets/editor/split_path2_auto_editor.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path2_auto_tree.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  testWidgets('shows an empty graph and a disabled zero-time seekbar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({PrefsKeys.treeOnRight: true});
    final prefs = await SharedPreferences.getInstance();
    final fs = MemoryFileSystem();
    final path = path2.Path.defaultPath(
      name: 'testPath',
      pathDir: '/paths',
      fs: fs,
    );
    final auto = Path2Auto.defaultAuto(
      name: 'testAuto',
      autoDir: '/autos',
      fs: fs,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplitPath2AutoEditor(
            prefs: prefs,
            auto: auto,
            allPaths: [path],
            allPathNames: [path.name],
            fieldImage: FieldImage.defaultField,
            undoStack: ChangeStack(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Path2AutoTree), findsOneWidget);
    expect(find.byKey(const ValueKey('path2AutoEmptyGraph')), findsOneWidget);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<Path2Painter>()
        .single;
    expect(painter.paintPaths, isEmpty);
    final seekbar = tester.widget<PreviewSeekbar>(find.byType(PreviewSeekbar));
    expect(seekbar.enabled, isFalse);
    expect(seekbar.totalPathTime, 0);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(find.textContaining('Simulated Driving Time'), findsNothing);
  });

  testWidgets('adds a path node transactionally and supports undo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({PrefsKeys.treeOnRight: true});
    final prefs = await SharedPreferences.getInstance();
    final fs = MemoryFileSystem();
    final path = path2.Path.defaultPath(
      name: 'testPath',
      pathDir: '/paths',
      fs: fs,
    );
    final auto = Path2Auto.defaultAuto(
      name: 'testAuto',
      autoDir: '/autos',
      fs: fs,
    );
    final undoStack = ChangeStack();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplitPath2AutoEditor(
            prefs: prefs,
            auto: auto,
            allPaths: [path],
            allPathNames: [path.name],
            fieldImage: FieldImage.defaultField,
            undoStack: undoStack,
            onAutoChanged: () {
              auto.initializeStartingPoseFromPaths([path]);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('path2AutoAddPathNode')));
    await tester.pumpAndSettle();
    expect(find.text('Select Path'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('path2AutoChoosePath-testPath')),
    );
    await tester.pumpAndSettle();

    expect(auto.nodes, hasLength(1));
    expect((auto.nodes.single as PathAutoNode).pathName, path.name);
    expect(auto.startingPoseInitialized, isTrue);
    expect(
      auto.startingPose.translation,
      path.rootNodes.single.waypoint.position,
    );
    expect(undoStack.canUndo, isTrue);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<Path2Painter>()
        .single;
    expect(painter.paintPaths, hasLength(1));
    expect(painter.paintPaths.single.occurrenceId, auto.nodes.single.id);

    undoStack.undo();
    await tester.pump();
    expect(auto.nodes, isEmpty);
    expect(auto.startingPoseInitialized, isFalse);
    expect(auto.startingPose.translation, const Translation2d());

    undoStack.redo();
    await tester.pump();
    expect(auto.nodes, hasLength(1));
    expect(auto.startingPoseInitialized, isTrue);
  });

  testWidgets('hover filters duplicate path occurrences by auto-node ID', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({PrefsKeys.treeOnRight: true});
    final prefs = await SharedPreferences.getInstance();
    final fs = MemoryFileSystem();
    final path = path2.Path.defaultPath(
      name: 'reusedPath',
      pathDir: '/paths',
      fs: fs,
    );
    final first = PathAutoNode(
      pathName: path.name,
      editorPosition: const Offset(20, 40),
    );
    final second = PathAutoNode(
      pathName: path.name,
      editorPosition: const Offset(340, 40),
    );
    final third = PathAutoNode(
      pathName: path.name,
      editorPosition: const Offset(340, 280),
    );
    final auto = Path2Auto(
      name: 'testAuto',
      // Deliberately not topologically ordered. A later-painted predecessor
      // must not cover the hovered occurrence when both reference this path.
      nodes: [second, first, third],
      branches: [
        AutoBranch(
          sourceId: first.id,
          targetId: second.id,
          transition: const FinishedTransition(),
        ),
        AutoBranch(
          sourceId: second.id,
          targetId: third.id,
          transition: const FinishedTransition(),
        ),
      ],
      autoDir: '/autos',
      fs: fs,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplitPath2AutoEditor(
            prefs: prefs,
            auto: auto,
            allPaths: [path],
            allPathNames: [path.name],
            fieldImage: FieldImage.defaultField,
            undoStack: ChangeStack(),
          ),
        ),
      ),
    );
    await tester.pump();

    Path2Painter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<Path2Painter>()
        .single;

    expect(painter().paintPaths.map((occurrence) => occurrence.occurrenceId), [
      second.id,
      first.id,
      third.id,
    ]);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(ValueKey('path2AutoNode-${second.id}'))),
    );
    await tester.pump();

    expect(painter().paintPaths.map((occurrence) => occurrence.occurrenceId), [
      first.id,
      second.id,
    ]);
    expect(painter().hoveredOccurrenceId, second.id);
  });

  testWidgets('edits parallel branch transitions independently with undo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fs = MemoryFileSystem();
    final source = PathAutoNode(
      pathName: 'firstPath',
      editorPosition: const Offset(40, 40),
    );
    final target = PathAutoNode(
      pathName: 'secondPath',
      editorPosition: const Offset(40, 330),
    );
    final finished = AutoBranch(
      sourceId: source.id,
      targetId: target.id,
      transition: const FinishedTransition(),
    );
    final conditional = AutoBranch(
      sourceId: source.id,
      targetId: target.id,
      transition: ConditionTransition(),
    );
    final auto = Path2Auto(
      name: 'testAuto',
      nodes: [source, target],
      branches: [finished, conditional],
      autoDir: '/autos',
      fs: fs,
    );
    final undoStack = ChangeStack();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Path2AutoTree(
            auto: auto,
            allPathNames: const ['firstPath', 'secondPath'],
            undoStack: undoStack,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(ValueKey('graphBranchBadge-${finished.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('graphBranchBadge-${conditional.id}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey('graphBranchBadge-${conditional.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Branch Transition'), findsOneWidget);
    final segmented = tester.widget<SegmentedButton<dynamic>>(
      find.byWidgetPredicate((widget) => widget is SegmentedButton),
    );
    expect(segmented.segments.first.enabled, isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('path2AutoConditionName')),
      'has-note',
    );
    await tester.enterText(
      find.byKey(const ValueKey('path2AutoConditionPreviewDistance')),
      '0.6',
    );
    await tester.tap(find.byKey(const ValueKey('path2AutoSaveTransition')));
    await tester.pumpAndSettle();

    final edited = auto.branches.singleWhere(
      (branch) => branch.id == conditional.id,
    );
    expect(
      (edited.transition as ConditionTransition).conditionName,
      'has-note',
    );
    expect(
      (edited.transition as ConditionTransition).previewDistanceMeters,
      0.6,
    );
    expect(undoStack.canUndo, isTrue);

    undoStack.undo();
    await tester.pump();
    final restored = auto.branches.singleWhere(
      (branch) => branch.id == conditional.id,
    );
    expect((restored.transition as ConditionTransition).conditionName, isNull);
  });

  testWidgets('drags the auto starting position as one undoable change', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      PrefsKeys.treeOnRight: true,
      PrefsKeys.robotWidth: 0.9,
      PrefsKeys.robotLength: 0.9,
      PrefsKeys.snapToGuidelines: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final fs = MemoryFileSystem();
    final path = path2.Path.defaultPath(
      name: 'testPath',
      pathDir: '/paths',
      fs: fs,
    );
    final originalPose = Pose2d(
      path.rootNodes.single.waypoint.position,
      const Rotation2d(),
    );
    final node = PathAutoNode(
      pathName: path.name,
      editorPosition: const Offset(20, 20),
    );
    final auto = Path2Auto(
      name: 'testAuto',
      nodes: [node],
      startingPose: originalPose,
      startingPoseInitialized: true,
      autoDir: '/autos',
      fs: fs,
    );
    final undoStack = ChangeStack();
    final fieldImage = FieldImage.official(OfficialField.chargedUp);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplitPath2AutoEditor(
            prefs: prefs,
            auto: auto,
            allPaths: [path],
            allPathNames: [path.name],
            fieldImage: fieldImage,
            undoStack: undoStack,
          ),
        ),
      ),
    );
    await tester.pump();

    final start =
        PathPainterUtil.pointToPixelOffset(
          originalPose.translation,
          Path2Painter.scale,
          fieldImage,
        ) +
        tester.getTopLeft(find.byKey(const ValueKey('path2AutoFieldGesture')));
    final meterPixels = PathPainterUtil.metersToPixels(
      1,
      Path2Painter.scale,
      fieldImage,
    );
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(Offset(meterPixels / 10, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(auto.startingPose.x, closeTo(originalPose.x + 1, 0.05));
    expect(auto.startingPose.y, closeTo(originalPose.y, 0.05));
    expect(undoStack.canUndo, isTrue);

    undoStack.undo();
    await tester.pump();
    expect(auto.startingPose.translation, originalPose.translation);
    expect(auto.startingPoseInitialized, true);
  });
}
