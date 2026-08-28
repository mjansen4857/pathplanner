import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/simulation/path2_simulator.dart';
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/graph_editor/path_graph_node_card.dart';
import 'package:pathplanner/widgets/editor/graph_editor/visual_graph_editor.dart';
import 'package:pathplanner/widgets/editor/path2_painter.dart';
import 'package:pathplanner/widgets/editor/preview_seekbar.dart';
import 'package:pathplanner/widgets/editor/split_path2_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late path2.Path path;
  late SharedPreferences prefs;
  late ChangeStack undoStack;
  late FieldImage fieldImage;

  setUp(() async {
    final fs = MemoryFileSystem();
    fs.directory('/paths').createSync(recursive: true);
    path = path2.Path.defaultPath(name: 'Path2', pathDir: '/paths', fs: fs);
    undoStack = ChangeStack();
    fieldImage = FieldImage.official(OfficialField.chargedUp);
    SharedPreferences.setMockInitialValues({
      PrefsKeys.treeOnRight: true,
      PrefsKeys.robotWidth: 1.0,
      PrefsKeys.robotLength: 0.8,
      PrefsKeys.bumperOffsetX: 0.0,
      PrefsKeys.bumperOffsetY: 0.0,
      PrefsKeys.showRobotDetails: false,
      PrefsKeys.showGrid: true,
      PrefsKeys.snapToGuidelines: true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplitPath2Editor(
            prefs: prefs,
            path: path,
            fieldImage: fieldImage,
            undoStack: undoStack,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'default distance path can be simulated with project preferences',
    () async {
      final outcome = await Path2Simulator.simulatePathInBackground(
        path,
        RobotConfig.fromPrefs(prefs),
      );

      expect(outcome.failure, isNull, reason: outcome.failure?.message);
      expect(outcome.result!.traversals, hasLength(1));
    },
  );

  testWidgets('shows graph cards and a stopped zero-time seekbar', (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.byType(VisualGraphEditor), findsOneWidget);
    expect(find.byType(Path2Painter), findsNothing);
    expect(
      find.byKey(ValueKey('graphNode-${path.nodes.first.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('graphNode-${path.nodes.last.id}')),
      findsOneWidget,
    );
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);

    final seekbar = tester.widget<PreviewSeekbar>(find.byType(PreviewSeekbar));
    expect(seekbar.enabled, isFalse);
    expect(seekbar.totalPathTime, 0);
    expect(seekbar.previewController.value, 0);
    expect(seekbar.previewController.isAnimating, isFalse);

    expect(find.text('Constraint Zones'), findsNothing);
    expect(find.text('Event Markers'), findsNothing);
    expect(find.text('Point Towards Zones'), findsNothing);
  });

  testWidgets('toolbar adds a disconnected field-centered node with undo', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('addPathNodeButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translation waypoint').last);
    await tester.pumpAndSettle();

    expect(path.nodes, hasLength(3));
    expect(path.branches, hasLength(1));
    expect(path.nodes.last.waypoint, isA<TranslationWaypoint>());
    expect(path.nodes.last.waypoint.position, const Translation2d());
    expect(find.byKey(const ValueKey('pathGraphDiagnostics')), findsOneWidget);

    undoStack.undo();
    await tester.pumpAndSettle();
    expect(path.nodes, hasLength(2));
    undoStack.redo();
    await tester.pumpAndSettle();
    expect(path.nodes, hasLength(3));
  });

  testWidgets('toolbar creates a point-towards waypoint', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('addPathNodeButton')));
    await tester.pumpAndSettle();

    expect(find.text('Point towards waypoint'), findsOneWidget);
    await tester.tap(find.text('Point towards waypoint'));
    await tester.pumpAndSettle();

    final waypoint = path.nodes.last.waypoint as PointTowardsWaypoint;
    expect(waypoint.position, const Translation2d());
    expect(waypoint.targetPosition, PointTowardsWaypoint.defaultTargetPosition);
    expect(waypoint.unprofiled, isFalse);
  });

  testWidgets('leaf tolerances depend on node and waypoint type', (
    tester,
  ) async {
    await pumpEditor(tester);
    final start = path.nodes.first;
    final end = path.nodes.last;
    await tester.tap(find.byKey(ValueKey('graphNode-${end.id}')));
    await tester.pump();

    expect(
      find.byKey(ValueKey('pathNodeDistanceTolerance-${start.id}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('pathNodeDistanceTolerance-${end.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('pathNodeAngleTolerance-${end.id}')),
      findsOneWidget,
    );

    final typeSelector = find.byKey(ValueKey('pathNodeType-${end.id}'));
    await tester.ensureVisible(typeSelector);
    await tester.tap(typeSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translation waypoint').last);
    await tester.pumpAndSettle();
    expect(path.nodeById(end.id)!.waypoint, isA<TranslationWaypoint>());
    expect(
      find.byKey(ValueKey('pathNodeDistanceTolerance-${end.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('pathNodeAngleTolerance-${end.id}')),
      findsNothing,
    );
  });

  testWidgets('selected pose node opens its settings in a floating panel', (
    tester,
  ) async {
    await pumpEditor(tester);
    final start = path.nodes.first;
    final card = find.byKey(ValueKey('graphNode-${start.id}'));
    final heading = find.byKey(ValueKey('pathNodeHeading-${start.id}'));

    expect(PathGraphNodeCard.sizeFor(path, start), PathGraphNodeCard.cardSize);
    expect(heading, findsNothing);
    await tester.tap(card);
    await tester.pump();

    final panel = find.byKey(ValueKey('pathNodeSettingsPanel-${start.id}'));
    expect(panel, findsOneWidget);
    expect(heading, findsOneWidget);
    expect(
      tester.getRect(panel).contains(tester.getRect(heading).center),
      isTrue,
    );
    expect(
      tester.getSize(panel).height,
      lessThan(540),
      reason: 'the panel should shrink to the height of its settings',
    );
    expect(
      find.descendant(of: panel, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'point-towards settings conditionally show inheritance and warnings',
    (tester) async {
      final fs = path.fs;
      final first = path2.PathNode(
        waypoint: PointTowardsWaypoint(
          position: const Translation2d(-2, 1),
          targetPosition: const Translation2d(1, 2),
        ),
        editorPosition: const Offset(80, 80),
      );
      final second = path2.PathNode(
        waypoint: PointTowardsWaypoint(
          position: const Translation2d(-2, -1),
          targetPosition: const Translation2d(3, 4),
        ),
        editorPosition: const Offset(420, 80),
      );
      final child = path2.PathNode(
        waypoint: PointTowardsWaypoint(
          position: const Translation2d(),
          inheritTargetFromParent: true,
        ),
        editorPosition: const Offset(250, 430),
      );
      path = path2.Path(
        name: 'Point settings',
        nodes: [first, second, child],
        branches: [
          path2.PathBranch(sourceId: second.id, targetId: child.id),
          path2.PathBranch(sourceId: first.id, targetId: child.id),
        ],
        fs: fs,
        pathDir: '/paths',
      );
      await pumpEditor(tester);

      await tester.tap(find.byKey(ValueKey('graphNode-${first.id}')));
      await tester.pump();
      expect(
        find.byKey(ValueKey('pathNodeInheritTarget-${first.id}')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('closePathNodeSettings')));
      await tester.pump();

      await tester.tap(find.byKey(ValueKey('graphNode-${child.id}')));
      await tester.pump();
      expect(
        find.byKey(ValueKey('pathNodeTargetX-${child.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('pathNodeTargetY-${child.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('pathNodeUnprofiled-${child.id}')),
        findsOneWidget,
      );
      final inheritToggle = find.byKey(
        ValueKey('pathNodeInheritTarget-${child.id}'),
      );
      final warning = find.byKey(
        ValueKey('pathNodeMultiplePointParentsWarning-${child.id}'),
      );
      expect(inheritToggle, findsOneWidget);
      expect(warning, findsOneWidget);
      expect(
        (child.waypoint as PointTowardsWaypoint).targetPosition,
        const Translation2d(3, 4),
      );

      await tester.ensureVisible(inheritToggle);
      await tester.tap(inheritToggle);
      await tester.pumpAndSettle();
      expect(warning, findsNothing);
    },
  );

  testWidgets('preview enables, animates, and displays the leaf runtime', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplitPath2Editor(
            prefs: prefs,
            path: path,
            fieldImage: fieldImage,
            undoStack: undoStack,
            simulatePath: (path, config) async =>
                Path2Simulator.simulateTraversals(
                  Path2Simulator.previewTraversals(path),
                  Path2RobotConfigSnapshot.fromRobotConfig(config),
                ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final seekbar = tester.widget<PreviewSeekbar>(find.byType(PreviewSeekbar));
    expect(seekbar.enabled, isTrue);
    expect(seekbar.totalPathTime, greaterThan(0));
    expect(seekbar.previewController.isAnimating, isTrue);
    expect(
      find.byKey(ValueKey('pathNodeRuntime-${path.nodes.last.id}')),
      findsOneWidget,
    );
    seekbar.previewController.stop();
  });

  testWidgets('clicking empty graph space deselects the waypoint', (
    tester,
  ) async {
    await pumpEditor(tester);
    final start = path.nodes.first;
    await tester.tap(find.byKey(ValueKey('graphNode-${start.id}')));
    await tester.pump();
    expect(
      find.byKey(ValueKey('pathNodeSettingsPanel-${start.id}')),
      findsOneWidget,
    );

    final graph = find.byType(VisualGraphEditor);
    await tester.tap(
      find.descendant(of: graph, matching: find.byTooltip('Fit Graph to View')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(graph) + const Offset(24, 24));
    await tester.pump();

    expect(find.byType(PathGraphNodeSettingsPanel), findsNothing);
  });

  testWidgets('condition branch edits its preview handoff distance', (
    tester,
  ) async {
    await pumpEditor(tester);
    final branch = path.branches.single;
    await tester.tap(find.byKey(ValueKey('graphBranchBadge-${branch.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pathTransitionType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Condition').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pathTransitionCondition')),
      'ready',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pathConditionPreviewDistance')),
      '0.8',
    );
    await tester.tap(find.byKey(const ValueKey('savePathTransitionButton')));
    await tester.pumpAndSettle();

    final transition = path.branches.single.transition as ConditionTransition;
    expect(transition.conditionName, 'ready');
    expect(transition.previewDistanceMeters, 0.8);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('graphBranchBadge-${branch.id}')),
        matching: find.textContaining('0.80 m'),
      ),
      findsNothing,
    );
  });

  testWidgets('field viewport fills the available editor pane', (tester) async {
    await pumpEditor(tester);
    final gesture = find.byKey(const ValueKey('path2FieldGesture'));
    final viewer = find.ancestor(
      of: gesture,
      matching: find.byType(InteractiveViewer),
    );

    expect(viewer, findsOneWidget);
    expect(tester.getSize(viewer).height, closeTo(900, 0.1));
    expect(
      tester.getRect(viewer).contains(tester.getRect(gesture).center),
      isTrue,
    );
  });

  testWidgets('branch deletion creates a saveable draft and is undoable', (
    tester,
  ) async {
    await pumpEditor(tester);
    final branchId = path.branches.single.id;
    await tester.tap(find.byKey(ValueKey('graphBranchBadge-$branchId')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Branch'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deletePathBranchButton')));
    await tester.pumpAndSettle();

    expect(path.branches, isEmpty);
    expect(path.diagnostics.hasWarnings, isTrue);
    expect(find.byKey(const ValueKey('pathGraphDiagnostics')), findsOneWidget);

    undoStack.undo();
    await tester.pumpAndSettle();
    expect(path.branches, hasLength(1));
  });

  testWidgets('cycle-producing connector is rejected', (tester) async {
    await pumpEditor(tester);
    final startTop = find.byKey(
      ValueKey('graphConnector-${path.nodes.first.id}-top'),
    );
    final endBottom = find.byKey(
      ValueKey('graphConnector-${path.nodes.last.id}-bottom'),
    );

    await tester.dragFrom(
      tester.getCenter(startTop),
      tester.getCenter(endBottom) - tester.getCenter(startTop),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(path.branches, hasLength(1));
    expect(find.text('That branch would create a cycle.'), findsOneWidget);
    expect(find.text('Create Branch'), findsNothing);
  });

  testWidgets('connector-to-empty cancellation is transactional', (
    tester,
  ) async {
    await pumpEditor(tester);
    final connector = find.byKey(
      ValueKey('graphConnector-${path.nodes.first.id}-bottom'),
    );
    final start = tester.getCenter(connector);
    await tester.dragFrom(
      start,
      const Offset(300, 80),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('Create Branch'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('newConnectedWaypointType')));
    await tester.pumpAndSettle();
    expect(find.text('Point towards waypoint'), findsOneWidget);
    await tester.tap(find.text('Translation waypoint').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(path.nodes, hasLength(2));
    expect(path.branches, hasLength(1));
  });

  testWidgets('field anchor drag commits one undoable node edit', (
    tester,
  ) async {
    await pumpEditor(tester);
    final node = path.nodes.last;
    final original = node.waypoint.position;
    final painterFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is Path2Painter,
    );
    final location =
        PathPainterUtil.pointToPixelOffset(
          original,
          Path2Painter.scale,
          fieldImage,
        ) +
        tester.getTopLeft(painterFinder);
    final meterPixels = PathPainterUtil.metersToPixels(
      1,
      Path2Painter.scale,
      fieldImage,
    );

    await tester.dragFrom(
      location,
      Offset(meterPixels, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      path.nodeById(node.id)!.waypoint.position.x,
      closeTo(original.x + 1, 0.06),
    );

    undoStack.undo();
    await tester.pumpAndSettle();
    expect(
      path.nodeById(node.id)!.waypoint.position.x,
      closeTo(original.x, 0.01),
    );
  });

  testWidgets(
    'inherited target drag wins hit testing and commits one undo step',
    (tester) async {
      final fs = path.fs;
      final parent = path2.PathNode(
        waypoint: PointTowardsWaypoint(
          position: const Translation2d(-2, 0),
          targetPosition: const Translation2d(),
        ),
        editorPosition: const Offset(100, 80),
      );
      final child = path2.PathNode(
        waypoint: PointTowardsWaypoint(
          position: const Translation2d(),
          targetPosition: const Translation2d(),
          inheritTargetFromParent: true,
        ),
        editorPosition: const Offset(100, 500),
      );
      path = path2.Path(
        name: 'Inherited drag',
        nodes: [parent, child],
        branches: [path2.PathBranch(sourceId: parent.id, targetId: child.id)],
        fs: fs,
        pathDir: '/paths',
      );
      await pumpEditor(tester);
      await tester.tap(find.byKey(ValueKey('graphNode-${child.id}')));
      await tester.pump();

      final painterFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is Path2Painter,
      );
      final targetLocation =
          PathPainterUtil.pointToPixelOffset(
            const Translation2d(),
            Path2Painter.scale,
            fieldImage,
          ) +
          tester.getTopLeft(painterFinder);
      final meterPixels = PathPainterUtil.metersToPixels(
        1,
        Path2Painter.scale,
        fieldImage,
      );

      await tester.dragFrom(
        targetLocation,
        Offset(meterPixels, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(path.nodeById(child.id)!.waypoint.position, const Translation2d());
      expect(
        (path.nodeById(parent.id)!.waypoint as PointTowardsWaypoint)
            .targetPosition
            .x,
        closeTo(1, 0.06),
      );
      expect(
        (path.nodeById(child.id)!.waypoint as PointTowardsWaypoint)
            .targetPosition
            .x,
        closeTo(1, 0.06),
      );
      expect(undoStack.canUndo, isTrue);

      undoStack.undo();
      await tester.pumpAndSettle();
      expect(undoStack.canUndo, isFalse);
      expect(
        (path.nodeById(parent.id)!.waypoint as PointTowardsWaypoint)
            .targetPosition,
        const Translation2d(),
      );
      expect(
        (path.nodeById(child.id)!.waypoint as PointTowardsWaypoint)
            .targetPosition,
        const Translation2d(),
      );

      undoStack.redo();
      await tester.pumpAndSettle();
      expect(
        (path.nodeById(child.id)!.waypoint as PointTowardsWaypoint)
            .targetPosition
            .x,
        closeTo(1, 0.06),
      );
    },
  );

  testWidgets('field click selects and centers by stable node id', (
    tester,
  ) async {
    await pumpEditor(tester);
    final node = path.nodes.first;
    final painterFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is Path2Painter,
    );
    final location =
        PathPainterUtil.pointToPixelOffset(
          node.waypoint.position,
          Path2Painter.scale,
          fieldImage,
        ) +
        tester.getTopLeft(painterFinder);

    await tester.tapAt(location);
    await tester.pumpAndSettle();

    final paint = tester.widget<CustomPaint>(painterFinder);
    expect((paint.painter as Path2Painter).selectedNodeId, node.id);
  });
}
