import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum GraphConnectorSide { top, bottom }

const double _branchBadgeWidth = 156;
const double _branchBadgeHeight = 40;

@immutable
class VisualGraphNode {
  final String id;
  final Offset position;
  final Size size;
  final Widget child;

  const VisualGraphNode({
    required this.id,
    required this.position,
    required this.size,
    required this.child,
  });
}

@immutable
class VisualGraphBranch {
  final String id;
  final String sourceId;
  final String targetId;
  final Widget badge;
  final Color? color;

  const VisualGraphBranch({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.badge,
    this.color,
  });
}

@immutable
class GraphConnectionRequest {
  final String sourceId;
  final String targetId;
  final Offset globalPosition;

  const GraphConnectionRequest({
    required this.sourceId,
    required this.targetId,
    required this.globalPosition,
  });
}

@immutable
class GraphEmptyConnectionRequest {
  final String nodeId;
  final GraphConnectorSide side;
  final Offset scenePosition;
  final Offset globalPosition;

  const GraphEmptyConnectionRequest({
    required this.nodeId,
    required this.side,
    required this.scenePosition,
    required this.globalPosition,
  });

  bool get existingNodeIsSource => side == GraphConnectorSide.bottom;
}

typedef GraphNodeMoved = void Function(
  String id,
  Offset oldPosition,
  Offset newPosition,
);

/// Computes rectilinear graph traces on a visibility grid built from card
/// boundaries. Segments are allowed to run along an inflated card edge, but
/// never through its interior.
abstract final class GraphBranchRouter {
  static List<Offset> route({
    required Offset start,
    required Offset end,
    required Iterable<Rect> obstacles,
    required Size canvasSize,
  }) {
    final obstacleList = obstacles.toList(growable: false);
    final xs = _uniqueSorted([
      0,
      canvasSize.width,
      start.dx,
      end.dx,
      for (final obstacle in obstacleList) ...[
        obstacle.left,
        obstacle.right,
      ],
    ]);
    final ys = _uniqueSorted([
      0,
      canvasSize.height,
      start.dy,
      end.dy,
      for (final obstacle in obstacleList) ...[
        obstacle.top,
        obstacle.bottom,
      ],
    ]);

    final startKey =
        (_indexOfCoordinate(xs, start.dx), _indexOfCoordinate(ys, start.dy));
    final endKey =
        (_indexOfCoordinate(xs, end.dx), _indexOfCoordinate(ys, end.dy));
    final open = HeapPriorityQueue<_RouteCandidate>(
      (a, b) => a.estimatedTotal.compareTo(b.estimatedTotal),
    )..add(_RouteCandidate(startKey, 0, _manhattan(start, end)));
    final scores = <(int, int), double>{startKey: 0};
    final previous = <(int, int), (int, int)>{};
    final closed = <(int, int)>{};

    while (open.isNotEmpty) {
      final candidate = open.removeFirst();
      final key = candidate.key;
      if (!closed.add(key)) {
        continue;
      }
      if (key == endKey) {
        return _simplifyRoute(
          _reconstructRoute(previous, key, xs, ys),
        );
      }

      final point = Offset(xs[key.$1], ys[key.$2]);
      for (final neighbor in _neighbors(
        key,
        xs,
        ys,
        obstacleList,
      )) {
        if (closed.contains(neighbor)) {
          continue;
        }
        final neighborPoint = Offset(xs[neighbor.$1], ys[neighbor.$2]);
        final score = candidate.distance + _manhattan(point, neighborPoint);
        if (score + 1e-9 >= (scores[neighbor] ?? double.infinity)) {
          continue;
        }
        scores[neighbor] = score;
        previous[neighbor] = key;
        open.add(
          _RouteCandidate(
            neighbor,
            score,
            score + _manhattan(neighborPoint, end),
          ),
        );
      }
    }

    // Overlapping cards can make the visibility grid unsolvable. Preserve a
    // usable trace in that malformed layout while the user drags cards apart.
    final middleY = (start.dy + end.dy) / 2;
    return _simplifyRoute([
      start,
      Offset(start.dx, middleY),
      Offset(end.dx, middleY),
      end,
    ]);
  }

  static Iterable<(int, int)> _neighbors(
    (int, int) key,
    List<double> xs,
    List<double> ys,
    List<Rect> obstacles,
  ) sync* {
    for (final step in const [-1, 1]) {
      for (var x = key.$1 + step; x >= 0 && x < xs.length; x += step) {
        final neighbor = (x, key.$2);
        final point = Offset(xs[x], ys[key.$2]);
        if (_insideObstacle(point, obstacles)) {
          continue;
        }
        final current = Offset(xs[key.$1], ys[key.$2]);
        if (!_segmentBlocked(current, point, obstacles)) {
          yield neighbor;
        }
        break;
      }
      for (var y = key.$2 + step; y >= 0 && y < ys.length; y += step) {
        final neighbor = (key.$1, y);
        final point = Offset(xs[key.$1], ys[y]);
        if (_insideObstacle(point, obstacles)) {
          continue;
        }
        final current = Offset(xs[key.$1], ys[key.$2]);
        if (!_segmentBlocked(current, point, obstacles)) {
          yield neighbor;
        }
        break;
      }
    }
  }

  static bool _insideObstacle(Offset point, Iterable<Rect> obstacles) {
    const epsilon = 1e-6;
    return obstacles.any(
      (rect) =>
          point.dx > rect.left + epsilon &&
          point.dx < rect.right - epsilon &&
          point.dy > rect.top + epsilon &&
          point.dy < rect.bottom - epsilon,
    );
  }

  static bool _segmentBlocked(
    Offset start,
    Offset end,
    Iterable<Rect> obstacles,
  ) {
    const epsilon = 1e-6;
    if ((start.dy - end.dy).abs() <= epsilon) {
      final left = min(start.dx, end.dx);
      final right = max(start.dx, end.dx);
      return obstacles.any(
        (rect) =>
            start.dy > rect.top + epsilon &&
            start.dy < rect.bottom - epsilon &&
            right > rect.left + epsilon &&
            left < rect.right - epsilon,
      );
    }
    final top = min(start.dy, end.dy);
    final bottom = max(start.dy, end.dy);
    return obstacles.any(
      (rect) =>
          start.dx > rect.left + epsilon &&
          start.dx < rect.right - epsilon &&
          bottom > rect.top + epsilon &&
          top < rect.bottom - epsilon,
    );
  }

  static List<Offset> _reconstructRoute(
    Map<(int, int), (int, int)> previous,
    (int, int) end,
    List<double> xs,
    List<double> ys,
  ) {
    final reversed = <Offset>[];
    var current = end;
    while (true) {
      reversed.add(Offset(xs[current.$1], ys[current.$2]));
      final prior = previous[current];
      if (prior == null) {
        break;
      }
      current = prior;
    }
    return reversed.reversed.toList(growable: false);
  }

  static List<double> _uniqueSorted(Iterable<double> values) {
    final sorted = values.where((value) => value.isFinite).toList()..sort();
    final unique = <double>[];
    for (final value in sorted) {
      if (unique.isEmpty || (unique.last - value).abs() > 1e-6) {
        unique.add(value);
      }
    }
    return unique;
  }

  static int _indexOfCoordinate(List<double> values, double coordinate) {
    for (var index = 0; index < values.length; index++) {
      if ((values[index] - coordinate).abs() <= 1e-6) {
        return index;
      }
    }
    throw StateError('Routing coordinate was not added to the grid');
  }

  static double _manhattan(Offset a, Offset b) =>
      (a.dx - b.dx).abs() + (a.dy - b.dy).abs();

  static List<Offset> _simplifyRoute(Iterable<Offset> route) {
    final simplified = <Offset>[];
    for (final point in route) {
      if (simplified.isNotEmpty && simplified.last == point) {
        continue;
      }
      while (simplified.length >= 2 &&
          _collinear(
            simplified[simplified.length - 2],
            simplified.last,
            point,
          )) {
        simplified.removeLast();
      }
      simplified.add(point);
    }
    return simplified;
  }

  static bool _collinear(Offset a, Offset b, Offset c) =>
      ((a.dx - b.dx).abs() <= 1e-6 && (b.dx - c.dx).abs() <= 1e-6) ||
      ((a.dy - b.dy).abs() <= 1e-6 && (b.dy - c.dy).abs() <= 1e-6);
}

class _RouteCandidate {
  final (int, int) key;
  final double distance;
  final double estimatedTotal;

  const _RouteCandidate(this.key, this.distance, this.estimatedTotal);
}

class VisualGraphController {
  _VisualGraphEditorState? _state;

  bool get attached => _state != null;

  Offset? get viewportCenterInScene => _state?._viewportCenterInScene;

  void fitToContent() => _state?._fitToContent();

  void centerNode(String nodeId) => _state?._centerNode(nodeId);
}

class VisualGraphEditor extends StatefulWidget {
  final List<VisualGraphNode> nodes;
  final List<VisualGraphBranch> branches;
  final VisualGraphController? controller;
  final GraphNodeMoved? onNodeMoved;
  final FutureOr<void> Function(GraphConnectionRequest request)? onConnect;
  final FutureOr<void> Function(GraphEmptyConnectionRequest request)?
      onConnectToEmpty;
  final void Function(String branchId, Offset globalPosition)? onBranchTap;
  final VoidCallback? onCanvasTap;
  final Color? branchColor;
  final Size canvasSize;
  final EdgeInsets contentPadding;

  const VisualGraphEditor({
    super.key,
    required this.nodes,
    required this.branches,
    this.controller,
    this.onNodeMoved,
    this.onConnect,
    this.onConnectToEmpty,
    this.onBranchTap,
    this.onCanvasTap,
    this.branchColor,
    this.canvasSize = const Size(4000, 4000),
    this.contentPadding = const EdgeInsets.all(80),
  });

  @override
  State<VisualGraphEditor> createState() => _VisualGraphEditorState();
}

class _VisualGraphEditorState extends State<VisualGraphEditor> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<String, Offset> _positions = {};

  _ConnectionDrag? _connectionDrag;
  String? _draggingNodeId;
  Offset? _dragStartPosition;

  @override
  void initState() {
    super.initState();
    _syncPositions();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant VisualGraphEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    _syncPositions();
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    _transformationController.dispose();
    super.dispose();
  }

  void _syncPositions() {
    final ids = widget.nodes.map((node) => node.id).toSet();
    _positions.removeWhere((id, _) => !ids.contains(id));
    for (final node in widget.nodes) {
      if (_draggingNodeId != node.id) {
        _positions[node.id] = node.position;
      }
    }
  }

  Offset? get _viewportCenterInScene {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return _transformationController.toScene(box.size.center(Offset.zero));
  }

  void _fitToContent() {
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize || widget.nodes.isEmpty) {
      return;
    }
    Rect bounds = _nodeRect(widget.nodes.first);
    for (final node in widget.nodes.skip(1)) {
      bounds = bounds.expandToInclude(_nodeRect(node));
    }
    for (final branch in _branchLayouts()) {
      bounds = bounds.expandToInclude(branch.bounds);
      bounds = bounds.expandToInclude(
        Rect.fromCenter(
          center: branch.badgeCenter,
          width: _branchBadgeWidth,
          height: _branchBadgeHeight,
        ),
      );
    }
    bounds = Rect.fromLTRB(
      bounds.left - widget.contentPadding.left,
      bounds.top - widget.contentPadding.top,
      bounds.right + widget.contentPadding.right,
      bounds.bottom + widget.contentPadding.bottom,
    );
    final scale = min(
      viewport.size.width / max(1, bounds.width),
      viewport.size.height / max(1, bounds.height),
    ).clamp(0.1, 2.0);
    _setView(bounds.center, scale);
  }

  void _centerNode(String nodeId) {
    final node = _nodeById(nodeId);
    if (node == null) {
      return;
    }
    final scale = _transformationController.value.getMaxScaleOnAxis();
    _setView(_nodeRect(node).center, scale.clamp(0.1, 3.0));
  }

  void _setView(Offset sceneCenter, double scale) {
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) {
      return;
    }
    final viewportCenter = viewport.size.center(Offset.zero);
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(
        0,
        3,
        viewportCenter.dx - sceneCenter.dx * scale,
      )
      ..setEntry(
        1,
        3,
        viewportCenter.dy - sceneCenter.dy * scale,
      );
    _transformationController.value = matrix;
  }

  Rect _nodeRect(VisualGraphNode node) => _positions[node.id]! & node.size;

  VisualGraphNode? _nodeById(String id) {
    for (final node in widget.nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final branchLayouts = _branchLayouts();

    return _GraphInteractionScope(
      state: this,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onCanvasTap,
              child: InteractiveViewer(
                key: _viewportKey,
                transformationController: _transformationController,
                constrained: false,
                minScale: 0.1,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(1200),
                child: SizedBox.fromSize(
                  size: widget.canvasSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _GraphBranchPainter(
                              layouts: branchLayouts,
                              provisional: _connectionDrag == null
                                  ? null
                                  : _provisionalLine(_connectionDrag!),
                              defaultColor: widget.branchColor ??
                                  colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                      for (final layout in branchLayouts)
                        Positioned(
                          key: ValueKey('graphBranchBadge-${layout.branch.id}'),
                          left: layout.badgeCenter.dx - _branchBadgeWidth / 2,
                          top: layout.badgeCenter.dy - _branchBadgeHeight / 2,
                          width: _branchBadgeWidth,
                          height: _branchBadgeHeight,
                          child: Center(
                            child: Material(
                              color: colorScheme.surfaceContainerHighest,
                              elevation: 2,
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTapDown: (details) =>
                                    widget.onBranchTap?.call(
                                  layout.branch.id,
                                  details.globalPosition,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  child: layout.branch.badge,
                                ),
                              ),
                            ),
                          ),
                        ),
                      for (final node in widget.nodes)
                        Positioned(
                          key: ValueKey('graphNode-${node.id}'),
                          left: _positions[node.id]!.dx,
                          top: _positions[node.id]!.dy,
                          width: node.size.width,
                          height: node.size.height,
                          child: node.child,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Tooltip(
              message: 'Fit Graph to View',
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: _fitToContent,
                child: const Icon(Icons.fit_screen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_BranchLayout> _branchLayouts() {
    final validBranches = widget.branches.where(
      (branch) =>
          _nodeById(branch.sourceId) != null &&
          _nodeById(branch.targetId) != null,
    );
    final groups = <(String, String), List<VisualGraphBranch>>{};
    for (final branch in validBranches) {
      groups.putIfAbsent(
          (branch.sourceId, branch.targetId), () => []).add(branch);
    }

    final layouts = <_BranchLayout>[];
    final occupiedBadgeRects = <Rect>[];
    final nodeRects = [
      for (final node in widget.nodes) _nodeRect(node),
    ];
    for (final branches in groups.values) {
      for (var index = 0; index < branches.length; index++) {
        final branch = branches[index];
        final source = _nodeById(branch.sourceId)!;
        final target = _nodeById(branch.targetId)!;
        final start = _connectorCenter(source, GraphConnectorSide.bottom);
        final end = _connectorCenter(target, GraphConnectorSide.top);
        final centeredIndex = index - (branches.length - 1) / 2;
        final laneOffset = centeredIndex * 22.0;
        final clearance = 28.0 + centeredIndex.abs() * 14.0;
        final sourceRect = _nodeRect(source);
        final targetRect = _nodeRect(target);
        final routeStart = Offset(
          start.dx + laneOffset,
          sourceRect.bottom + clearance,
        );
        final routeEnd = Offset(
          end.dx + laneOffset,
          targetRect.top - clearance,
        );
        final obstacles = [
          for (final rect in nodeRects) rect.inflate(clearance),
        ];
        final coreRoute = GraphBranchRouter.route(
          start: routeStart,
          end: routeEnd,
          obstacles: obstacles,
          canvasSize: widget.canvasSize,
        );
        final points = _simplifyPolyline([
          start,
          Offset(start.dx, routeStart.dy),
          routeStart,
          ...coreRoute.skip(1).take(max(0, coreRoute.length - 2)),
          routeEnd,
          Offset(end.dx, routeEnd.dy),
          end,
        ]);
        final badgeCenter = _badgeCenterForRoute(
          points,
          nodeRects,
          occupiedBadgeRects,
        );
        occupiedBadgeRects.add(
          Rect.fromCenter(
            center: badgeCenter,
            width: _branchBadgeWidth,
            height: _branchBadgeHeight,
          ),
        );
        layouts.add(
          _BranchLayout(
            branch,
            points,
            badgeCenter,
          ),
        );
      }
    }
    return layouts;
  }

  _ProvisionalLine _provisionalLine(_ConnectionDrag drag) {
    final node = _nodeById(drag.nodeId);
    final start =
        node == null ? drag.scenePosition : _connectorCenter(node, drag.side);
    return _ProvisionalLine(start, drag.scenePosition);
  }

  List<Offset> _simplifyPolyline(Iterable<Offset> points) {
    final result = <Offset>[];
    for (final point in points) {
      if (result.isNotEmpty && (result.last - point).distance <= 1e-6) {
        continue;
      }
      while (result.length >= 2 &&
          _pointsAreCollinear(result[result.length - 2], result.last, point)) {
        result.removeLast();
      }
      result.add(point);
    }
    return result;
  }

  bool _pointsAreCollinear(Offset a, Offset b, Offset c) =>
      ((a.dx - b.dx).abs() <= 1e-6 && (b.dx - c.dx).abs() <= 1e-6) ||
      ((a.dy - b.dy).abs() <= 1e-6 && (b.dy - c.dy).abs() <= 1e-6);

  Offset _badgeCenterForRoute(
    List<Offset> points,
    List<Rect> nodeRects,
    List<Rect> occupiedBadgeRects,
  ) {
    final candidates = <({Offset point, double distanceFromMiddle})>[];
    final totalLength = _polylineLength(points);
    var traveled = 0.0;
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      final length = (end - start).distance;
      for (final fraction in const [0.5, 0.25, 0.75]) {
        final distance = traveled + length * fraction;
        candidates.add(
          (
            point: Offset.lerp(start, end, fraction)!,
            distanceFromMiddle: (distance - totalLength / 2).abs(),
          ),
        );
      }
      traveled += length;
    }
    candidates.sort(
      (a, b) => a.distanceFromMiddle.compareTo(b.distanceFromMiddle),
    );
    for (final candidate in candidates) {
      final rect = Rect.fromCenter(
        center: candidate.point,
        width: _branchBadgeWidth,
        height: _branchBadgeHeight,
      );
      if (nodeRects.every((node) => !rect.overlaps(node.inflate(4))) &&
          occupiedBadgeRects
              .every((badge) => !rect.overlaps(badge.inflate(4)))) {
        return candidate.point;
      }
    }
    return _pointAtPolylineDistance(points, totalLength / 2);
  }

  double _polylineLength(List<Offset> points) {
    var length = 0.0;
    for (var index = 0; index < points.length - 1; index++) {
      length += (points[index + 1] - points[index]).distance;
    }
    return length;
  }

  Offset _pointAtPolylineDistance(List<Offset> points, double distance) {
    var remaining = distance;
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      final segmentLength = (end - start).distance;
      if (remaining <= segmentLength || index == points.length - 2) {
        return Offset.lerp(
          start,
          end,
          segmentLength <= 1e-9 ? 0 : remaining / segmentLength,
        )!;
      }
      remaining -= segmentLength;
    }
    return points.last;
  }

  Offset _connectorCenter(
    VisualGraphNode node,
    GraphConnectorSide side,
  ) {
    final rect = _nodeRect(node);
    return Offset(
      rect.center.dx,
      side == GraphConnectorSide.top ? rect.top + 14 : rect.bottom - 14,
    );
  }

  void _startNodeDrag(String id) {
    _draggingNodeId = id;
    _dragStartPosition = _positions[id];
  }

  void _updateNodeDrag(String id, Offset sceneDelta) {
    if (_draggingNodeId != id || _positions[id] == null) {
      return;
    }
    setState(() {
      // Drag details are reported in the transformed child's local (scene)
      // coordinate system, so applying the graph zoom again over-corrects the
      // movement—most noticeably after fitting a large graph to the viewport.
      _positions[id] = _positions[id]! + sceneDelta;
    });
  }

  void _endNodeDrag(String id) {
    if (_draggingNodeId != id) {
      return;
    }
    final oldPosition = _dragStartPosition;
    final newPosition = _positions[id];
    _draggingNodeId = null;
    _dragStartPosition = null;
    if (oldPosition != null &&
        newPosition != null &&
        oldPosition != newPosition) {
      widget.onNodeMoved?.call(id, oldPosition, newPosition);
    }
  }

  void _startConnection(
    String id,
    GraphConnectorSide side,
    Offset globalPosition,
  ) {
    setState(() {
      _connectionDrag = _ConnectionDrag(
        id,
        side,
        _globalToScene(globalPosition),
        globalPosition,
      );
    });
  }

  void _updateConnection(Offset globalPosition) {
    final drag = _connectionDrag;
    if (drag == null) {
      return;
    }
    setState(() {
      _connectionDrag = drag.copyWith(
        scenePosition: _globalToScene(globalPosition),
        globalPosition: globalPosition,
      );
    });
  }

  Future<void> _endConnection(Offset globalPosition) async {
    final drag = _connectionDrag;
    if (drag == null) {
      return;
    }
    final scenePosition = _globalToScene(globalPosition);
    setState(() => _connectionDrag = null);

    final target = _connectorHitTest(scenePosition);
    if (target != null) {
      if (target.nodeId == drag.nodeId || target.side == drag.side) {
        return;
      }
      final sourceId =
          drag.side == GraphConnectorSide.bottom ? drag.nodeId : target.nodeId;
      final targetId =
          drag.side == GraphConnectorSide.bottom ? target.nodeId : drag.nodeId;
      await widget.onConnect?.call(
        GraphConnectionRequest(
          sourceId: sourceId,
          targetId: targetId,
          globalPosition: globalPosition,
        ),
      );
      return;
    }

    if (widget.nodes.any((node) => _nodeRect(node).contains(scenePosition))) {
      return;
    }
    if (_branchLayouts().any(
      (layout) => Rect.fromCenter(
        center: layout.badgeCenter,
        width: _branchBadgeWidth,
        height: _branchBadgeHeight,
      ).contains(scenePosition),
    )) {
      return;
    }

    await widget.onConnectToEmpty?.call(
      GraphEmptyConnectionRequest(
        nodeId: drag.nodeId,
        side: drag.side,
        scenePosition: scenePosition,
        globalPosition: globalPosition,
      ),
    );
  }

  void _cancelConnection() {
    if (_connectionDrag != null) {
      setState(() => _connectionDrag = null);
    }
  }

  _ConnectorTarget? _connectorHitTest(Offset scenePosition) {
    const hitRadius = 28.0;
    _ConnectorTarget? closest;
    var closestDistance = double.infinity;
    for (final node in widget.nodes) {
      for (final side in GraphConnectorSide.values) {
        final distance =
            (_connectorCenter(node, side) - scenePosition).distance;
        if (distance <= hitRadius && distance < closestDistance) {
          closest = _ConnectorTarget(node.id, side);
          closestDistance = distance;
        }
      }
    }
    return closest;
  }

  Offset _globalToScene(Offset globalPosition) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return globalPosition;
    }
    return _transformationController.toScene(
      box.globalToLocal(globalPosition),
    );
  }
}

class GraphNodeDragHandle extends StatelessWidget {
  final String nodeId;
  final Widget child;

  const GraphNodeDragHandle({
    super.key,
    required this.nodeId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final state = _GraphInteractionScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => state._startNodeDrag(nodeId),
        onPanUpdate: (details) => state._updateNodeDrag(nodeId, details.delta),
        onPanEnd: (_) => state._endNodeDrag(nodeId),
        onPanCancel: () => state._endNodeDrag(nodeId),
        child: child,
      ),
    );
  }
}

class GraphConnectorHandle extends StatelessWidget {
  final String nodeId;
  final GraphConnectorSide side;
  final Color? color;
  final double size;

  const GraphConnectorHandle({
    super.key,
    required this.nodeId,
    required this.side,
    this.color,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final state = _GraphInteractionScope.of(context);
    final handleColor = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '${side.name} connector for $nodeId',
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: GestureDetector(
          key: ValueKey('graphConnector-$nodeId-${side.name}'),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (details) => state._startConnection(
            nodeId,
            side,
            details.globalPosition,
          ),
          onPanUpdate: (details) =>
              state._updateConnection(details.globalPosition),
          onPanEnd: (details) => state._endConnection(details.globalPosition),
          onPanCancel: state._cancelConnection,
          child: SizedBox.square(
            dimension: max(28, size),
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: handleColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(blurRadius: 2, color: Colors.black38),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphInteractionScope extends InheritedWidget {
  final _VisualGraphEditorState state;

  const _GraphInteractionScope({
    required this.state,
    required super.child,
  });

  static _VisualGraphEditorState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_GraphInteractionScope>();
    assert(scope != null, 'Graph handles must be below a VisualGraphEditor');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_GraphInteractionScope oldWidget) =>
      oldWidget.state != state;
}

class _GraphBranchPainter extends CustomPainter {
  final List<_BranchLayout> layouts;
  final _ProvisionalLine? provisional;
  final Color defaultColor;

  const _GraphBranchPainter({
    required this.layouts,
    required this.provisional,
    required this.defaultColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final layout in layouts) {
      _paintDottedPath(
        canvas,
        _roundedOrthogonalPath(layout.points),
        layout.branch.color ?? defaultColor,
      );
    }
    final preview = provisional;
    if (preview != null) {
      _paintDottedLine(
        canvas,
        preview.start,
        preview.end,
        defaultColor.withAlpha(190),
        dashLength: 8,
        gapLength: 5,
        strokeWidth: 2.5,
      );
    }
  }

  static Path _roundedOrthogonalPath(
    List<Offset> points, {
    double radius = 12,
  }) {
    final path = Path();
    if (points.isEmpty) {
      return path;
    }
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) {
      return path;
    }
    for (var index = 1; index < points.length - 1; index++) {
      final previous = points[index - 1];
      final corner = points[index];
      final next = points[index + 1];
      final incoming = corner - previous;
      final outgoing = next - corner;
      final incomingLength = incoming.distance;
      final outgoingLength = outgoing.distance;
      if (incomingLength <= 1e-6 || outgoingLength <= 1e-6) {
        continue;
      }
      final cornerRadius = min(
        radius,
        min(incomingLength / 2, outgoingLength / 2),
      );
      final beforeCorner = corner - incoming / incomingLength * cornerRadius;
      final afterCorner = corner + outgoing / outgoingLength * cornerRadius;
      path
        ..lineTo(beforeCorner.dx, beforeCorner.dy)
        ..quadraticBezierTo(
          corner.dx,
          corner.dy,
          afterCorner.dx,
          afterCorner.dy,
        );
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  static void _paintDottedPath(
    Canvas canvas,
    Path path,
    Color color, {
    double dashLength = 5,
    double gapLength = 5,
    double strokeWidth = 2,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0;
          offset < metric.length;
          offset += dashLength + gapLength) {
        canvas.drawPath(
          metric.extractPath(
            offset,
            min(metric.length, offset + dashLength),
          ),
          paint,
        );
      }
    }
  }

  static void _paintDottedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color, {
    double dashLength = 5,
    double gapLength = 5,
    double strokeWidth = 2,
  }) {
    final vector = end - start;
    final distance = vector.distance;
    if (distance <= 0) {
      return;
    }
    final unit = vector / distance;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (double offset = 0;
        offset < distance;
        offset += dashLength + gapLength) {
      canvas.drawLine(
        start + unit * offset,
        start + unit * min(distance, offset + dashLength),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphBranchPainter oldDelegate) => true;
}

class _BranchLayout {
  final VisualGraphBranch branch;
  final List<Offset> points;
  final Offset badgeCenter;

  const _BranchLayout(this.branch, this.points, this.badgeCenter);

  Rect get bounds {
    var left = points.first.dx;
    var top = points.first.dy;
    var right = points.first.dx;
    var bottom = points.first.dy;
    for (final point in points.skip(1)) {
      left = min(left, point.dx);
      top = min(top, point.dy);
      right = max(right, point.dx);
      bottom = max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class _ProvisionalLine {
  final Offset start;
  final Offset end;

  const _ProvisionalLine(this.start, this.end);
}

class _ConnectorTarget {
  final String nodeId;
  final GraphConnectorSide side;

  const _ConnectorTarget(this.nodeId, this.side);
}

class _ConnectionDrag {
  final String nodeId;
  final GraphConnectorSide side;
  final Offset scenePosition;
  final Offset globalPosition;

  const _ConnectionDrag(
    this.nodeId,
    this.side,
    this.scenePosition,
    this.globalPosition,
  );

  _ConnectionDrag copyWith({
    Offset? scenePosition,
    Offset? globalPosition,
  }) {
    return _ConnectionDrag(
      nodeId,
      side,
      scenePosition ?? this.scenePosition,
      globalPosition ?? this.globalPosition,
    );
  }
}
