import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';

/// Common data exposed by nodes that can be placed in a graph editor.
abstract interface class GraphNodeData {
  String get id;

  Offset get editorPosition;

  set editorPosition(Offset value);
}

/// Common data exposed by directed graph branches.
abstract interface class GraphBranchData {
  String get id;

  String get sourceId;

  String get targetId;
}

/// Schema failures are never saveable. Draft and configuration warnings are.
class GraphDiagnostics {
  final List<String> hardErrors;
  final List<String> draftWarnings;
  final List<String> configurationWarnings;

  GraphDiagnostics({
    Iterable<String> hardErrors = const [],
    Iterable<String> draftWarnings = const [],
    Iterable<String> configurationWarnings = const [],
  }) : hardErrors = List.unmodifiable(hardErrors),
       draftWarnings = List.unmodifiable(draftWarnings),
       configurationWarnings = List.unmodifiable(configurationWarnings);

  List<String> get warnings =>
      List.unmodifiable([...draftWarnings, ...configurationWarnings]);

  bool get hasHardErrors => hardErrors.isNotEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get isComplete => !hasHardErrors && !hasWarnings;

  @override
  bool operator ==(Object other) =>
      other is GraphDiagnostics &&
      const ListEquality<String>().equals(other.hardErrors, hardErrors) &&
      const ListEquality<String>().equals(other.draftWarnings, draftWarnings) &&
      const ListEquality<String>().equals(
        other.configurationWarnings,
        configurationWarnings,
      );

  @override
  int get hashCode => Object.hash(
    const ListEquality<String>().hash(hardErrors),
    const ListEquality<String>().hash(draftWarnings),
    const ListEquality<String>().hash(configurationWarnings),
  );
}

/// Algorithms shared by path and auto directed acyclic multigraphs.
class GraphAlgorithms {
  GraphAlgorithms._();

  static List<N> roots<N extends GraphNodeData, B extends GraphBranchData>(
    Iterable<N> nodes,
    Iterable<B> branches,
  ) {
    final targets = {for (final branch in branches) branch.targetId};
    return [
      for (final node in nodes)
        if (!targets.contains(node.id)) node,
    ];
  }

  static List<N> leaves<N extends GraphNodeData, B extends GraphBranchData>(
    Iterable<N> nodes,
    Iterable<B> branches,
  ) {
    final sources = {for (final branch in branches) branch.sourceId};
    return [
      for (final node in nodes)
        if (!sources.contains(node.id)) node,
    ];
  }

  /// Returns [nodeId] and every node that can reach it.
  static Set<String> reverseReachableNodeIds<B extends GraphBranchData>(
    String nodeId,
    Iterable<B> branches,
  ) {
    final incoming = <String, List<String>>{};
    for (final branch in branches) {
      incoming.putIfAbsent(branch.targetId, () => []).add(branch.sourceId);
    }

    final visited = <String>{};
    final pending = <String>[nodeId];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) {
        continue;
      }
      pending.addAll(incoming[current] ?? const []);
    }
    return visited;
  }

  /// Returns [nodeId] and every node reachable from it.
  static Set<String> reachableNodeIds<B extends GraphBranchData>(
    String nodeId,
    Iterable<B> branches,
  ) {
    final outgoing = <String, List<String>>{};
    for (final branch in branches) {
      outgoing.putIfAbsent(branch.sourceId, () => []).add(branch.targetId);
    }

    final visited = <String>{};
    final pending = <String>[nodeId];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) {
        continue;
      }
      pending.addAll(outgoing[current] ?? const []);
    }
    return visited;
  }

  static bool hasCycle<N extends GraphNodeData, B extends GraphBranchData>(
    Iterable<N> nodes,
    Iterable<B> branches,
  ) {
    final nodeIds = {for (final node in nodes) node.id};
    final outgoing = <String, List<String>>{};
    for (final branch in branches) {
      if (nodeIds.contains(branch.sourceId) &&
          nodeIds.contains(branch.targetId)) {
        outgoing.putIfAbsent(branch.sourceId, () => []).add(branch.targetId);
      }
    }

    final states = <String, int>{};
    bool visit(String nodeId) {
      final state = states[nodeId] ?? 0;
      if (state == 1) {
        return true;
      }
      if (state == 2) {
        return false;
      }

      states[nodeId] = 1;
      for (final target in outgoing[nodeId] ?? const []) {
        if (visit(target)) {
          return true;
        }
      }
      states[nodeId] = 2;
      return false;
    }

    return nodeIds.any(visit);
  }

  static bool wouldCreateCycle<B extends GraphBranchData>(
    String sourceId,
    String targetId,
    Iterable<B> branches,
  ) {
    if (sourceId == targetId) {
      return true;
    }
    return reachableNodeIds(targetId, branches).contains(sourceId);
  }
}

/// Generates an RFC 4122 version-4 UUID without adding a runtime dependency.
String generateGraphId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

class EndTolerance {
  static const num defaultDistanceMeters = 0.1;
  static const num defaultAngleDegrees = 2.0;

  num distanceMeters;
  num angleDegrees;

  EndTolerance({
    this.distanceMeters = defaultDistanceMeters,
    this.angleDegrees = defaultAngleDegrees,
  }) {
    _validateNonNegativeFinite(distanceMeters, 'distanceMeters');
    _validateNonNegativeFinite(angleDegrees, 'angleDegrees');
  }

  factory EndTolerance.fromJson(Object? value) {
    final json = _jsonObject(value, 'endTolerance');
    return EndTolerance(
      distanceMeters: _requiredFiniteNum(
        json,
        'distanceMeters',
        nonNegative: true,
      ),
      angleDegrees: _requiredFiniteNum(json, 'angleDegrees', nonNegative: true),
    );
  }

  EndTolerance clone() =>
      EndTolerance(distanceMeters: distanceMeters, angleDegrees: angleDegrees);

  Map<String, dynamic> toJson() => {
    'distanceMeters': distanceMeters,
    'angleDegrees': angleDegrees,
  };

  @override
  bool operator ==(Object other) =>
      other is EndTolerance &&
      other.distanceMeters == distanceMeters &&
      other.angleDegrees == angleDegrees;

  @override
  int get hashCode => Object.hash(distanceMeters, angleDegrees);
}

sealed class PathTransition {
  const PathTransition();

  String get type;

  PathTransition clone();

  Map<String, dynamic> toJson();

  static PathTransition fromJson(Object? value) {
    final json = _jsonObject(value, 'Path transition');
    final type = json['type'];
    if (type is! String) {
      throw const FormatException('Path transition type must be a string');
    }
    return switch (type) {
      'distance' => DistanceTransition.fromJson(json),
      'condition' => ConditionTransition.fromJson(json),
      _ => throw FormatException('Unknown path transition type: $type'),
    };
  }
}

sealed class AutoTransition {
  const AutoTransition();

  String get type;

  AutoTransition clone();

  Map<String, dynamic> toJson();

  static AutoTransition fromJson(Object? value) {
    final json = _jsonObject(value, 'Auto transition');
    final type = json['type'];
    if (type is! String) {
      throw const FormatException('Auto transition type must be a string');
    }
    return switch (type) {
      'finished' => const FinishedTransition(),
      'condition' => ConditionTransition.fromJson(json),
      _ => throw FormatException('Unknown auto transition type: $type'),
    };
  }
}

final class DistanceTransition extends PathTransition {
  static const num defaultDistanceMeters = 0.25;

  num distanceMeters;

  DistanceTransition({this.distanceMeters = defaultDistanceMeters}) {
    _validateNonNegativeFinite(distanceMeters, 'distanceMeters');
  }

  factory DistanceTransition.fromJson(Map<String, dynamic> json) =>
      DistanceTransition(
        distanceMeters: _requiredFiniteNum(
          json,
          'distanceMeters',
          nonNegative: true,
        ),
      );

  @override
  String get type => 'distance';

  @override
  DistanceTransition clone() =>
      DistanceTransition(distanceMeters: distanceMeters);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'distanceMeters': distanceMeters,
  };

  @override
  bool operator ==(Object other) =>
      other is DistanceTransition && other.distanceMeters == distanceMeters;

  @override
  int get hashCode => Object.hash(type, distanceMeters);
}

final class ConditionTransition implements PathTransition, AutoTransition {
  static const num defaultPreviewDistanceMeters = 0.25;

  String? conditionName;
  num previewDistanceMeters;

  ConditionTransition({
    this.conditionName,
    this.previewDistanceMeters = defaultPreviewDistanceMeters,
  }) {
    _validateNonNegativeFinite(previewDistanceMeters, 'previewDistanceMeters');
  }

  factory ConditionTransition.fromJson(Map<String, dynamic> json) {
    final conditionName = json['conditionName'];
    if (conditionName != null && conditionName is! String) {
      throw const FormatException('conditionName must be a string or null');
    }
    final previewDistance = json['previewDistanceMeters'];
    if (previewDistance != null &&
        (previewDistance is! num ||
            !previewDistance.isFinite ||
            previewDistance < 0)) {
      throw const FormatException(
        'previewDistanceMeters must be a non-negative finite number',
      );
    }
    return ConditionTransition(
      conditionName: conditionName as String?,
      previewDistanceMeters:
          previewDistance as num? ?? defaultPreviewDistanceMeters,
    );
  }

  @override
  String get type => 'condition';

  @override
  ConditionTransition clone() => ConditionTransition(
    conditionName: conditionName,
    previewDistanceMeters: previewDistanceMeters,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'conditionName': conditionName,
    'previewDistanceMeters': previewDistanceMeters,
  };

  @override
  bool operator ==(Object other) =>
      other is ConditionTransition &&
      other.conditionName == conditionName &&
      other.previewDistanceMeters == previewDistanceMeters;

  @override
  int get hashCode => Object.hash(type, conditionName, previewDistanceMeters);
}

final class FinishedTransition extends AutoTransition {
  const FinishedTransition();

  @override
  String get type => 'finished';

  @override
  FinishedTransition clone() => const FinishedTransition();

  @override
  Map<String, dynamic> toJson() => {'type': type};

  @override
  bool operator ==(Object other) => other is FinishedTransition;

  @override
  int get hashCode => type.hashCode;
}

Offset editorPositionFromJson(Object? value) {
  final json = _jsonObject(value, 'editorPosition');
  return Offset(
    _requiredFiniteNum(json, 'x').toDouble(),
    _requiredFiniteNum(json, 'y').toDouble(),
  );
}

Map<String, dynamic> editorPositionToJson(Offset position) {
  _validateOffset(position);
  return {'x': position.dx, 'y': position.dy};
}

bool isFiniteOffset(Offset value) => value.dx.isFinite && value.dy.isFinite;

void validateFiniteOffset(Offset value, String name) {
  if (!isFiniteOffset(value)) {
    throw ArgumentError.value(value, name, 'Offset must be finite');
  }
}

Map<String, dynamic> _jsonObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('$label must be an object');
  }
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw FormatException('$label must have string keys');
  }
}

num _requiredFiniteNum(
  Map<String, dynamic> json,
  String key, {
  bool nonNegative = false,
}) {
  final value = json[key];
  if (value is! num || !value.isFinite || (nonNegative && value < 0)) {
    final qualifier = nonNegative ? 'a finite non-negative number' : 'finite';
    throw FormatException('$key must be $qualifier');
  }
  return value;
}

void _validateNonNegativeFinite(num value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and non-negative');
  }
}

void _validateOffset(Offset value) => validateFiniteOffset(value, 'position');
