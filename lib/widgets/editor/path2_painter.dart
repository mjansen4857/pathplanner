import 'dart:convert';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/robot_features/feature.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One occurrence of a path on the field.
///
/// Autos can reference the same path more than once. [occurrenceId] keeps
/// those references independently filterable even though their path node IDs
/// are identical.
@immutable
class Path2PaintPath {
  final path2.Path path;
  final String occurrenceId;
  final Set<String>? visibleNodeIds;

  Path2PaintPath({
    required this.path,
    String? occurrenceId,
    Set<String>? visibleNodeIds,
  }) : occurrenceId = occurrenceId ?? path.name,
       visibleNodeIds = visibleNodeIds == null
           ? null
           : Set<String>.unmodifiable(visibleNodeIds);
}

/// Paints Path 2 graphs and all simulated root-to-leaf preview traversals.
class Path2Painter extends CustomPainter {
  final ColorScheme colorScheme;
  final List<Path2PaintPath> paintPaths;
  final FieldImage fieldImage;
  final SharedPreferences prefs;
  final bool simple;
  final String? hoveredOccurrenceId;
  final String? hoveredNodeId;
  final String? selectedNodeId;
  final Pose2d? autoStartingPose;
  final bool showStartingPoseHandles;
  final bool showWaypointRobotPreviews;
  final List<Path2SimulationResult> simulations;
  final Animation<double>? animation;
  final double simulationDurationSeconds;

  late final Size robotSize;
  late final Translation2d bumperOffset;
  late final double robotRadius;
  final List<Feature> robotFeatures = [];

  static double scale = 1;

  Path2Painter({
    required this.colorScheme,
    required this.paintPaths,
    required this.fieldImage,
    required this.prefs,
    this.simple = false,
    this.hoveredOccurrenceId,
    this.hoveredNodeId,
    this.selectedNodeId,
    this.autoStartingPose,
    this.showStartingPoseHandles = false,
    this.showWaypointRobotPreviews = true,
    this.simulations = const [],
    this.animation,
    this.simulationDurationSeconds = 0,
  }) : super(repaint: animation) {
    robotSize = Size(
      prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth,
      prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength,
    );
    bumperOffset = Translation2d(
      prefs.getDouble(PrefsKeys.bumperOffsetX) ?? Defaults.bumperOffsetX,
      prefs.getDouble(PrefsKeys.bumperOffsetY) ?? Defaults.bumperOffsetY,
    );
    robotRadius =
        sqrt(
          robotSize.width * robotSize.width +
              robotSize.height * robotSize.height,
        ) /
        2.0;

    for (final featureJson
        in prefs.getStringList(PrefsKeys.robotFeatures) ??
            Defaults.robotFeatures) {
      try {
        final feature = Feature.fromJson(jsonDecode(featureJson));
        if (feature != null) {
          robotFeatures.add(feature);
        }
      } catch (_) {
        // An optional malformed robot feature must not break graph editing.
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;
    _paintGrid(canvas, size);

    for (final occurrence in paintPaths) {
      _paintBranches(occurrence, canvas);
    }
    _paintSimulationTraces(canvas);
    for (final occurrence in paintPaths) {
      for (final node in occurrence.path.nodes) {
        if (_isVisible(occurrence, node.id)) {
          _paintNode(occurrence, node, canvas);
        }
      }
    }

    final startingPose = autoStartingPose;
    if (startingPose != null) {
      _paintAutoStartingPose(canvas, startingPose);
    }
    _paintSimulationPreviews(canvas);
  }

  void _paintSimulationTraces(Canvas canvas) {
    for (
      var traversalIndex = 0;
      traversalIndex < simulations.length;
      traversalIndex++
    ) {
      final simulation = simulations[traversalIndex];
      final trace = Path();
      for (
        var sampleIndex = 0;
        sampleIndex < simulation.samples.length;
        sampleIndex++
      ) {
        final point = PathPainterUtil.pointToPixelOffset(
          simulation.samples[sampleIndex].pose.translation,
          scale,
          fieldImage,
        );
        if (sampleIndex == 0) {
          trace.moveTo(point.dx, point.dy);
        } else {
          trace.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        trace,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _previewColor.withAlpha(150),
      );
    }
  }

  void _paintSimulationPreviews(Canvas canvas) {
    if (simulations.isEmpty) {
      return;
    }
    final time = (animation?.value ?? 0) * simulationDurationSeconds;
    for (
      var traversalIndex = 0;
      traversalIndex < simulations.length;
      traversalIndex++
    ) {
      final simulation = simulations[traversalIndex];
      final sample = simulation.sampleAt(
        time.clamp(0, simulation.totalTimeSeconds).toDouble(),
      );
      _paintRobotModules(canvas, sample);
      PathPainterUtil.paintRobotOutline(
        sample.pose,
        fieldImage,
        robotSize,
        bumperOffset,
        scale,
        canvas,
        _previewColor,
        colorScheme.surfaceContainer.withAlpha(190),
        robotFeatures,
        showDetails:
            prefs.getBool(PrefsKeys.showRobotDetails) ??
            Defaults.showRobotDetails,
      );
    }
  }

  Color get _previewColor => colorScheme.primary;

  void _paintRobotModules(Canvas canvas, Path2SimulationSample sample) {
    final locations = <Translation2d>[
      Translation2d(
        prefs.getDouble(PrefsKeys.flModuleX) ?? Defaults.flModuleX,
        prefs.getDouble(PrefsKeys.flModuleY) ?? Defaults.flModuleY,
      ),
      Translation2d(
        prefs.getDouble(PrefsKeys.frModuleX) ?? Defaults.frModuleX,
        prefs.getDouble(PrefsKeys.frModuleY) ?? Defaults.frModuleY,
      ),
      Translation2d(
        prefs.getDouble(PrefsKeys.blModuleX) ?? Defaults.blModuleX,
        prefs.getDouble(PrefsKeys.blModuleY) ?? Defaults.blModuleY,
      ),
      Translation2d(
        prefs.getDouble(PrefsKeys.brModuleX) ?? Defaults.brModuleX,
        prefs.getDouble(PrefsKeys.brModuleY) ?? Defaults.brModuleY,
      ),
    ];
    final moduleCount = min(locations.length, sample.moduleStates.length);
    final modulePoses = <Pose2d>[
      for (var index = 0; index < moduleCount; index++)
        Pose2d(
          sample.pose.translation +
              locations[index].rotateBy(sample.pose.rotation),
          sample.pose.rotation + sample.moduleStates[index].angle,
        ),
    ];
    PathPainterUtil.paintRobotModules(
      modulePoses,
      fieldImage,
      scale,
      canvas,
      _previewColor,
    );
  }

  void _paintBranches(Path2PaintPath occurrence, Canvas canvas) {
    final path = occurrence.path;
    final groups = <(String, String), List<path2.PathBranch>>{};
    for (final branch in path.branches) {
      if (!_isVisible(occurrence, branch.sourceId) ||
          !_isVisible(occurrence, branch.targetId)) {
        continue;
      }
      groups
          .putIfAbsent((branch.sourceId, branch.targetId), () => [])
          .add(branch);
    }

    for (final branches in groups.values) {
      for (var index = 0; index < branches.length; index++) {
        final branch = branches[index];
        final source = path.nodeById(branch.sourceId);
        final target = path.nodeById(branch.targetId);
        if (source == null || target == null) {
          continue;
        }
        final start = PathPainterUtil.pointToPixelOffset(
          source.waypoint.position,
          scale,
          fieldImage,
        );
        final end = PathPainterUtil.pointToPixelOffset(
          target.waypoint.position,
          scale,
          fieldImage,
        );
        final vector = end - start;
        final distance = vector.distance;
        final normal = distance <= 0
            ? Offset.zero
            : Offset(-vector.dy / distance, vector.dx / distance);
        final parallelOffset = (index - (branches.length - 1) / 2) * 6.0;
        _paintDottedLine(
          canvas,
          start + normal * parallelOffset,
          end + normal * parallelOffset,
          simple && occurrence.occurrenceId == hoveredOccurrenceId
              ? Colors.orange
              : Colors.grey.shade600,
        );
      }
    }
  }

  bool _isVisible(Path2PaintPath occurrence, String nodeId) =>
      occurrence.visibleNodeIds?.contains(nodeId) ?? true;

  void _paintDottedLine(Canvas canvas, Offset start, Offset end, Color color) {
    final vector = end - start;
    final distance = vector.distance;
    if (distance <= 0) {
      return;
    }
    final unit = vector / distance;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    const dash = 4.0;
    const gap = 5.0;
    for (double offset = 0; offset < distance; offset += dash + gap) {
      canvas.drawLine(
        start + unit * offset,
        start + unit * min(distance, offset + dash),
        paint,
      );
    }
  }

  void _paintNode(
    Path2PaintPath occurrence,
    path2.PathNode node,
    Canvas canvas,
  ) {
    final waypoint = node.waypoint;
    final center = PathPainterUtil.pointToPixelOffset(
      waypoint.position,
      scale,
      fieldImage,
    );
    final color = _nodeColor(occurrence, node);

    if (waypoint is PoseWaypoint && showWaypointRobotPreviews) {
      PathPainterUtil.paintRobotOutline(
        Pose2d(waypoint.position, waypoint.rotation),
        fieldImage,
        robotSize,
        bumperOffset,
        scale,
        canvas,
        color.withAlpha(160),
        colorScheme.surfaceContainer,
        robotFeatures,
        showDetails:
            prefs.getBool(PrefsKeys.showRobotDetails) ??
            Defaults.showRobotDetails,
      );
    } else if (waypoint is TranslationWaypoint) {
      canvas.drawCircle(
        center,
        PathPainterUtil.metersToPixels(robotRadius, scale, fieldImage),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withAlpha(160),
      );
    }

    final roots = occurrence.path.rootNodes;
    final leaves = occurrence.path.leafNodes;
    final isRoot = roots.any((root) => root.id == node.id);
    final isLeaf = leaves.any((leaf) => leaf.id == node.id);
    final radius = PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage);

    if (isRoot && isLeaf && !_isHighlighted(occurrence, node.id)) {
      canvas.drawCircle(center, radius, Paint()..color = Colors.green);
      canvas.drawCircle(center, radius * 0.45, Paint()..color = Colors.red);
    } else {
      canvas.drawCircle(center, radius, Paint()..color = color);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colorScheme.surfaceContainer,
    );
    if (!simple && waypoint is PoseWaypoint) {
      _paintPoseHeadingHandle(canvas, waypoint, color);
    }
  }

  void _paintPoseHeadingHandle(
    Canvas canvas,
    PoseWaypoint waypoint,
    Color color,
  ) {
    final handlePosition =
        waypoint.position +
        Translation2d(
          robotSize.height / 2 + bumperOffset.x,
          bumperOffset.y,
        ).rotateBy(waypoint.rotation);
    final handle = PathPainterUtil.pointToPixelOffset(
      handlePosition,
      scale,
      fieldImage,
    );
    final radius = PathPainterUtil.uiPointSizeToPixels(14, scale, fieldImage);
    canvas.drawCircle(handle, radius, Paint()..color = color);
    canvas.drawCircle(
      handle,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colorScheme.surfaceContainer,
    );
  }

  bool _isHighlighted(Path2PaintPath occurrence, String nodeId) =>
      (!simple && (nodeId == selectedNodeId || nodeId == hoveredNodeId)) ||
      (simple && occurrence.occurrenceId == hoveredOccurrenceId);

  Color _nodeColor(Path2PaintPath occurrence, path2.PathNode node) {
    if (!simple && node.id == selectedNodeId) {
      return Colors.orange;
    }
    if (!simple && node.id == hoveredNodeId) {
      return Colors.deepPurpleAccent;
    }
    if (simple && occurrence.occurrenceId == hoveredOccurrenceId) {
      return Colors.orange;
    }
    if (occurrence.path.rootNodes.any((root) => root.id == node.id)) {
      return Colors.green;
    }
    if (occurrence.path.leafNodes.any((leaf) => leaf.id == node.id)) {
      return Colors.red;
    }
    return colorScheme.secondary;
  }

  void _paintAutoStartingPose(Canvas canvas, Pose2d pose) {
    const color = Colors.green;
    PathPainterUtil.paintRobotOutline(
      pose,
      fieldImage,
      robotSize,
      bumperOffset,
      scale,
      canvas,
      color.withAlpha(190),
      colorScheme.surfaceContainer.withAlpha(120),
      robotFeatures,
      showDetails: false,
    );
    if (!showStartingPoseHandles) {
      return;
    }

    final center = PathPainterUtil.pointToPixelOffset(
      pose.translation,
      scale,
      fieldImage,
    );
    final handlePosition =
        pose.translation +
        Translation2d(
          robotSize.height / 2 + bumperOffset.x,
          bumperOffset.y,
        ).rotateBy(pose.rotation);
    final handle = PathPainterUtil.pointToPixelOffset(
      handlePosition,
      scale,
      fieldImage,
    );
    final anchorRadius = PathPainterUtil.uiPointSizeToPixels(
      20,
      scale,
      fieldImage,
    );
    final rotationRadius = PathPainterUtil.uiPointSizeToPixels(
      14,
      scale,
      fieldImage,
    );
    canvas.drawCircle(center, anchorRadius, Paint()..color = color);
    canvas.drawCircle(handle, rotationRadius, Paint()..color = color);
    for (final circle in [(center, anchorRadius), (handle, rotationRadius)]) {
      canvas.drawCircle(
        circle.$1,
        circle.$2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colorScheme.surfaceContainer,
      );
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    if (!(prefs.getBool(PrefsKeys.showGrid) ?? Defaults.showGrid)) {
      return;
    }
    final paint = Paint()
      ..color = colorScheme.secondary.withAlpha(50)
      ..strokeWidth = 1;
    final spacing = PathPainterUtil.metersToPixels(0.5, scale, fieldImage);
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant Path2Painter oldDelegate) => true;
}
