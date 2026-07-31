import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/editor/graph_editor/visual_graph_editor.dart';

void main() {
  test('routes orthogonal branches around card obstacles', () {
    const obstacle = Rect.fromLTWH(180, 120, 160, 180);
    final route = GraphBranchRouter.route(
      start: const Offset(120, 160),
      end: const Offset(400, 260),
      obstacles: const [obstacle],
      canvasSize: const Size(600, 500),
    );

    expect(route.first, const Offset(120, 160));
    expect(route.last, const Offset(400, 260));
    expect(route.length, greaterThan(2));
    for (var index = 0; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      expect(
        start.dx == end.dx || start.dy == end.dy,
        isTrue,
        reason: 'segment $start -> $end must be orthogonal',
      );
      final middle = Offset.lerp(start, end, 0.5)!;
      expect(
        middle.dx > obstacle.left &&
            middle.dx < obstacle.right &&
            middle.dy > obstacle.top &&
            middle.dy < obstacle.bottom,
        isFalse,
        reason: 'segment $start -> $end crossed the card',
      );
    }
  });

  Widget node(String id, Color color) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: color,
          child: Column(
            children: [
              GraphNodeDragHandle(
                nodeId: id,
                child: SizedBox(
                  key: ValueKey('header-$id'),
                  height: 40,
                  child: Center(child: Text(id)),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 66,
          child: GraphConnectorHandle(
            nodeId: id,
            side: GraphConnectorSide.top,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 66,
          child: GraphConnectorHandle(
            nodeId: id,
            side: GraphConnectorSide.bottom,
          ),
        ),
      ],
    );
  }

  Future<void> pumpGraph(
    WidgetTester tester, {
    GraphNodeMoved? onNodeMoved,
    Future<void> Function(GraphConnectionRequest)? onConnect,
    Future<void> Function(GraphEmptyConnectionRequest)? onConnectToEmpty,
    void Function(String, Offset)? onBranchTap,
    Offset secondNodePosition = const Offset(100, 400),
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualGraphEditor(
            nodes: [
              VisualGraphNode(
                id: 'one',
                position: const Offset(100, 100),
                size: const Size(160, 120),
                child: node('one', Colors.blue.shade100),
              ),
              VisualGraphNode(
                id: 'two',
                position: secondNodePosition,
                size: const Size(160, 120),
                child: node('two', Colors.green.shade100),
              ),
            ],
            branches: const [
              VisualGraphBranch(
                id: 'first',
                sourceId: 'one',
                targetId: 'two',
                badge: Text('0.25 m'),
              ),
              VisualGraphBranch(
                id: 'parallel',
                sourceId: 'one',
                targetId: 'two',
                badge: Text('? ready'),
              ),
            ],
            onNodeMoved: onNodeMoved,
            onConnect: onConnect,
            onConnectToEmpty: onConnectToEmpty,
            onBranchTap: onBranchTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders independently clickable parallel branch badges',
      (tester) async {
    final tapped = <String>[];
    await pumpGraph(
      tester,
      onBranchTap: (id, _) => tapped.add(id),
    );

    expect(
        find.byKey(const ValueKey('graphBranchBadge-first')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('graphBranchBadge-parallel')),
      findsOneWidget,
    );
    await tester.tap(find.text('0.25 m'));
    await tester.pump();
    await tester.tap(find.text('? ready'));
    await tester.pump();
    expect(tapped, ['first', 'parallel']);
  });

  testWidgets('header drag commits one logical editor position',
      (tester) async {
    final moves = <(String, Offset, Offset)>[];
    await pumpGraph(
      tester,
      onNodeMoved: (id, oldPosition, newPosition) =>
          moves.add((id, oldPosition, newPosition)),
    );

    final header = find.byKey(const ValueKey('header-one'));
    await tester.dragFrom(
      tester.getTopLeft(header) + const Offset(28, 22),
      const Offset(80, 35),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(moves, hasLength(1));
    expect(moves.single.$1, 'one');
    expect(moves.single.$2, const Offset(100, 100));
    expect(moves.single.$3.dx, closeTo(180, 0.01));
    expect(moves.single.$3.dy, closeTo(135, 0.01));
  });

  testWidgets('header drag follows the pointer after fitting a large graph',
      (tester) async {
    await pumpGraph(
      tester,
      secondNodePosition: const Offset(100, 1200),
    );
    await tester.tap(find.byTooltip('Fit Graph to View'));
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('header-one'));
    final before = tester.getCenter(header);
    final dragStart = tester.getTopLeft(header) + const Offset(10, 10);
    const pointerMovement = Offset(30, 20);
    await tester.dragFrom(
      dragStart,
      pointerMovement,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    final screenMovement = tester.getCenter(header) - before;
    expect(screenMovement.dx, closeTo(pointerMovement.dx, 1));
    expect(screenMovement.dy, closeTo(pointerMovement.dy, 1));
  });

  testWidgets('bottom-to-top and top-to-bottom connectors set direction',
      (tester) async {
    final requests = <GraphConnectionRequest>[];
    await pumpGraph(
      tester,
      onConnect: (request) async => requests.add(request),
    );

    final oneBottom = find.byKey(
      const ValueKey('graphConnector-one-bottom'),
    );
    final twoTop = find.byKey(const ValueKey('graphConnector-two-top'));
    await tester.dragFrom(
      tester.getCenter(oneBottom),
      tester.getCenter(twoTop) - tester.getCenter(oneBottom),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(requests.single.sourceId, 'one');
    expect(requests.single.targetId, 'two');

    final oneTop = find.byKey(const ValueKey('graphConnector-one-top'));
    final twoBottom = find.byKey(
      const ValueKey('graphConnector-two-bottom'),
    );
    await tester.dragFrom(
      tester.getCenter(oneTop),
      tester.getCenter(twoBottom) - tester.getCenter(oneTop),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.last.sourceId, 'two');
    expect(requests.last.targetId, 'one');
  });

  testWidgets('same-side and self drops are rejected', (tester) async {
    final requests = <GraphConnectionRequest>[];
    final emptyRequests = <GraphEmptyConnectionRequest>[];
    await pumpGraph(
      tester,
      onConnect: (request) async => requests.add(request),
      onConnectToEmpty: (request) async => emptyRequests.add(request),
    );

    final oneTop = find.byKey(const ValueKey('graphConnector-one-top'));
    final twoTop = find.byKey(const ValueKey('graphConnector-two-top'));
    await tester.dragFrom(
      tester.getCenter(oneTop),
      tester.getCenter(twoTop) - tester.getCenter(oneTop),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    final oneBottom = find.byKey(
      const ValueKey('graphConnector-one-bottom'),
    );
    await tester.dragFrom(
      tester.getCenter(oneTop),
      tester.getCenter(oneBottom) - tester.getCenter(oneTop),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
    expect(emptyRequests, isEmpty);
  });

  testWidgets('dropping a connector on canvas reports its scene position',
      (tester) async {
    GraphEmptyConnectionRequest? request;
    await pumpGraph(
      tester,
      onConnectToEmpty: (value) async => request = value,
    );
    final handle = find.byKey(
      const ValueKey('graphConnector-one-bottom'),
    );
    final start = tester.getCenter(handle);
    const target = Offset(600, 300);
    await tester.dragFrom(
      start,
      target - start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(request, isNotNull);
    expect(request!.nodeId, 'one');
    expect(request!.existingNodeIsSource, isTrue);
    expect(request!.scenePosition.dx, closeTo(target.dx, 1));
    expect(request!.scenePosition.dy, closeTo(target.dy, 1));
  });

  testWidgets('dropping over a card body does not create an overlapping node',
      (tester) async {
    final requests = <GraphEmptyConnectionRequest>[];
    await pumpGraph(
      tester,
      onConnectToEmpty: (request) async => requests.add(request),
    );
    final handle = find.byKey(
      const ValueKey('graphConnector-one-bottom'),
    );
    final start = tester.getCenter(handle);
    final target = tester.getTopLeft(find.byKey(const ValueKey('header-two'))) +
        const Offset(24, 24);
    await tester.dragFrom(
      start,
      target - start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
  });

  testWidgets('dropping over a branch badge is not an empty-canvas drop',
      (tester) async {
    final requests = <GraphEmptyConnectionRequest>[];
    await pumpGraph(
      tester,
      onConnectToEmpty: (request) async => requests.add(request),
    );
    final handle = find.byKey(
      const ValueKey('graphConnector-one-bottom'),
    );
    final start = tester.getCenter(handle);
    final target = tester.getCenter(find.text('? ready'));
    await tester.dragFrom(
      start,
      target - start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
  });
}
