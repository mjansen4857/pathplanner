import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/pathplanner_auto.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/path2_painter.dart';
import 'package:pathplanner/widgets/editor/preview_seekbar.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path2_auto_tree.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

/// Split field/graph editor for Path 2 autos.
///
/// Path 2 graph previews are intentionally static. The seekbar remains visible
/// to preserve the editor layout, but it is stopped at zero and disabled.
class SplitPath2AutoEditor extends StatefulWidget {
  final SharedPreferences prefs;
  final Path2Auto auto;
  final List<path2.Path> allPaths;
  final List<String> allPathNames;
  final VoidCallback? onAutoChanged;
  final FieldImage fieldImage;
  final ChangeStack undoStack;
  final ValueChanged<String?>? onEditPathPressed;

  const SplitPath2AutoEditor({
    super.key,
    required this.prefs,
    required this.auto,
    required this.allPaths,
    required this.allPathNames,
    required this.fieldImage,
    required this.undoStack,
    this.onAutoChanged,
    this.onEditPathPressed,
  });

  @override
  State<SplitPath2AutoEditor> createState() => _SplitPath2AutoEditorState();
}

class _SplitPath2AutoEditorState extends State<SplitPath2AutoEditor>
    with SingleTickerProviderStateMixin {
  final MultiSplitViewController _controller = MultiSplitViewController();
  late final AnimationController _previewController;
  late bool _treeOnRight;
  String? _hoveredAutoNodeId;
  Offset? _panDownPosition;
  bool _draggingStartingPosition = false;
  bool _draggingStartingRotation = false;
  _StartingPoseSnapshot? _startingPoseBeforeDrag;
  late final Size _robotSize;
  late final Translation2d _bumperOffset;

  @override
  void initState() {
    super.initState();
    _previewController = AnimationController(vsync: this, value: 0);
    _treeOnRight =
        widget.prefs.getBool(PrefsKeys.treeOnRight) ?? Defaults.treeOnRight;
    _robotSize = Size(
      widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth,
      widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength,
    );
    _bumperOffset = Translation2d(
      widget.prefs.getDouble(PrefsKeys.bumperOffsetX) ?? Defaults.bumperOffsetX,
      widget.prefs.getDouble(PrefsKeys.bumperOffsetY) ?? Defaults.bumperOffsetY,
    );
    final treeWeight =
        widget.prefs.getDouble(PrefsKeys.editorTreeWeight) ??
        Defaults.editorTreeWeight;
    _controller.areas = [
      Area(
        weight: _treeOnRight ? 1 - treeWeight : treeWeight,
        minimalWeight: 0.4,
      ),
      Area(
        weight: _treeOnRight ? treeWeight : 1 - treeWeight,
        minimalWeight: 0.4,
      ),
    ];
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleOccurrences = _visiblePathOccurrences();

    final seekbar = PreviewSeekbar(
      previewController: _previewController,
      onPauseStateChanged: (_) {},
      totalPathTime: 0,
      enabled: false,
    );
    final graph = Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: _treeOnRight ? const Radius.circular(12) : Radius.zero,
          topRight: _treeOnRight ? Radius.zero : const Radius.circular(12),
          bottomLeft: _treeOnRight ? const Radius.circular(12) : Radius.zero,
          bottomRight: _treeOnRight ? Radius.zero : const Radius.circular(12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Path2AutoTree(
          auto: widget.auto,
          allPathNames: widget.allPathNames,
          undoStack: widget.undoStack,
          onNodeHovered: (nodeId) {
            setState(() => _hoveredAutoNodeId = nodeId);
          },
          onAutoChanged: () {
            widget.onAutoChanged?.call();
            setState(() {});
          },
          onEditPathPressed: widget.onEditPathPressed,
          onSideSwapped: _swapTreeSide,
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 10,
            boundaryMargin: const EdgeInsets.all(200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
              child: Center(
                child: AspectRatio(
                  aspectRatio:
                      widget.fieldImage.defaultSize.width /
                      widget.fieldImage.defaultSize.height,
                  child: GestureDetector(
                    key: const ValueKey('path2AutoFieldGesture'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    onPanDown: (details) =>
                        _panDownPosition = details.localPosition,
                    onPanStart: _handlePanStart,
                    onPanUpdate: _handlePanUpdate,
                    onPanEnd: (_) => _finishStartingPoseDrag(),
                    onPanCancel: _finishStartingPoseDrag,
                    child: Stack(
                      children: [
                        widget.fieldImage.getWidget(),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: Path2Painter(
                              colorScheme: colorScheme,
                              paintPaths: visibleOccurrences,
                              fieldImage: widget.fieldImage,
                              prefs: widget.prefs,
                              simple: true,
                              hoveredOccurrenceId: _hoveredAutoNodeId,
                              autoStartingPose: widget.auto.startingPose,
                              showStartingPoseHandles: true,
                              showWaypointRobotPreviews: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        MultiSplitViewTheme(
          data: MultiSplitViewThemeData(
            dividerPainter: DividerPainters.grooved1(
              color: colorScheme.surfaceContainerHighest,
              highlightedColor: colorScheme.primary,
            ),
          ),
          child: MultiSplitView(
            axis: Axis.horizontal,
            controller: _controller,
            onWeightChange: () {
              final newWeight = _treeOnRight
                  ? _controller.areas[1].weight
                  : _controller.areas[0].weight;
              widget.prefs.setDouble(
                PrefsKeys.editorTreeWeight,
                newWeight ?? Defaults.editorTreeWeight,
              );
            },
            children: _treeOnRight ? [seekbar, graph] : [graph, seekbar],
          ),
        ),
      ],
    );
  }

  /// Resolves paths by auto-node occurrence, rather than collapsing them by
  /// path name. This makes predecessor filtering deterministic even when two
  /// auto nodes reference the same path.
  List<Path2PaintPath> _visiblePathOccurrences() {
    final hoveredId = _hoveredAutoNodeId;
    final visibleNodeIds = hoveredId == null
        ? {for (final node in widget.auto.nodes) node.id}
        : widget.auto.reverseReachableNodeIds(hoveredId);
    final occurrences = <Path2PaintPath>[];
    for (final node in widget.auto.nodes) {
      if (!visibleNodeIds.contains(node.id) || node is! PathAutoNode) {
        continue;
      }
      final pathName = node.pathName;
      if (pathName == null) {
        continue;
      }
      path2.Path? resolved;
      for (final candidate in widget.allPaths) {
        if (candidate.name == pathName) {
          resolved = candidate;
          break;
        }
      }
      if (resolved != null) {
        occurrences.add(Path2PaintPath(path: resolved, occurrenceId: node.id));
      }
    }
    // Duplicate auto nodes can reference the exact same path geometry. Paint
    // the hovered occurrence last so a later unhighlighted duplicate cannot
    // cover its highlighted waypoints.
    if (hoveredId != null) {
      final hoveredIndex = occurrences.indexWhere(
        (occurrence) => occurrence.occurrenceId == hoveredId,
      );
      if (hoveredIndex >= 0 && hoveredIndex != occurrences.length - 1) {
        occurrences.add(occurrences.removeAt(hoveredIndex));
      }
    }
    return occurrences;
  }

  void _swapTreeSide() {
    setState(() {
      _treeOnRight = !_treeOnRight;
      widget.prefs.setBool(PrefsKeys.treeOnRight, _treeOnRight);
      _controller.areas = _controller.areas.reversed.toList();
    });
  }

  void _handlePanStart(DragStartDetails details) {
    final localPosition = _panDownPosition ?? details.localPosition;
    _panDownPosition = null;
    final pointer = Translation2d(
      _xPixelsToMeters(localPosition.dx),
      _yPixelsToMeters(localPosition.dy),
    );
    final pose = widget.auto.startingPose;
    final rotationHandle = _startingRotationHandlePosition(pose);
    final rotationRadius = _pixelsToMeters(
      PathPainterUtil.uiPointSizeToPixels(
        16,
        Path2Painter.scale,
        widget.fieldImage,
      ),
    );
    final positionRadius = _pixelsToMeters(
      PathPainterUtil.uiPointSizeToPixels(
        25,
        Path2Painter.scale,
        widget.fieldImage,
      ),
    );

    if (rotationHandle.getDistance(pointer) < rotationRadius) {
      _startingPoseBeforeDrag = _StartingPoseSnapshot(
        pose,
        widget.auto.startingPoseInitialized,
      );
      _draggingStartingRotation = true;
    } else if (pose.translation.getDistance(pointer) < positionRadius) {
      _startingPoseBeforeDrag = _StartingPoseSnapshot(
        pose,
        widget.auto.startingPoseInitialized,
      );
      _draggingStartingPosition = true;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggingStartingRotation) {
      final x = _xPixelsToMeters(details.localPosition.dx);
      final y = _yPixelsToMeters(details.localPosition.dy);
      final pose = widget.auto.startingPose;
      setState(() {
        widget.auto.startingPose = Pose2d(
          pose.translation,
          Rotation2d.fromComponents(x - pose.x, y - pose.y),
        );
      });
      return;
    }
    if (!_draggingStartingPosition) {
      return;
    }

    var targetX = _xPixelsToMeters(
      details.localPosition.dx.clamp(
        0,
        widget.fieldImage.defaultSize.width * Path2Painter.scale,
      ),
    );
    var targetY = _yPixelsToMeters(
      details.localPosition.dy.clamp(
        0,
        widget.fieldImage.defaultSize.height * Path2Painter.scale,
      ),
    );
    final snapSetting =
        widget.prefs.getBool(PrefsKeys.snapToGuidelines) ??
        Defaults.snapToGuidelines;
    final ctrlHeld =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlRight,
        );
    if (snapSetting ^ ctrlHeld) {
      final waypointPositions = widget.allPaths
          .expand((path) => path.nodes)
          .map((node) => node.waypoint.position);
      num? closestX;
      num? closestY;
      for (final position in waypointPositions) {
        if (closestX == null ||
            (targetX - position.x).abs() < (targetX - closestX).abs()) {
          closestX = position.x;
        }
        if (closestY == null ||
            (targetY - position.y).abs() < (targetY - closestY).abs()) {
          closestY = position.y;
        }
      }
      if (closestX != null && (targetX - closestX).abs() < 0.1) {
        targetX = closestX.toDouble();
      }
      if (closestY != null && (targetY - closestY).abs() < 0.1) {
        targetY = closestY.toDouble();
      }
    }

    final pose = widget.auto.startingPose;
    setState(() {
      widget.auto.startingPose = Pose2d(
        Translation2d(targetX, targetY),
        pose.rotation,
      );
    });
  }

  void _finishStartingPoseDrag() {
    _panDownPosition = null;
    final before = _startingPoseBeforeDrag;
    if (before == null ||
        (!_draggingStartingPosition && !_draggingStartingRotation)) {
      _clearStartingPoseDrag();
      return;
    }
    final after = widget.auto.startingPose;
    _clearStartingPoseDrag();
    if (_samePose(before.pose, after)) {
      return;
    }

    widget.undoStack.add(
      Change<_StartingPoseSnapshot>(
        before,
        () {
          setState(() => widget.auto.setStartingPose(after));
          widget.onAutoChanged?.call();
        },
        (oldValue) {
          setState(() {
            widget.auto.startingPose = oldValue.pose;
            widget.auto.startingPoseInitialized = oldValue.initialized;
          });
          widget.onAutoChanged?.call();
        },
      ),
    );
  }

  void _clearStartingPoseDrag() {
    _draggingStartingPosition = false;
    _draggingStartingRotation = false;
    _startingPoseBeforeDrag = null;
  }

  Translation2d _startingRotationHandlePosition(Pose2d pose) {
    return pose.translation +
        Translation2d(
          _robotSize.height / 2 + _bumperOffset.x,
          _bumperOffset.y,
        ).rotateBy(pose.rotation);
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels / Path2Painter.scale) / widget.fieldImage.pixelsPerMeter) -
        widget.fieldImage.marginMeters;
  }

  double _yPixelsToMeters(double pixels) {
    return ((widget.fieldImage.defaultSize.height -
                pixels / Path2Painter.scale) /
            widget.fieldImage.pixelsPerMeter) -
        widget.fieldImage.marginMeters;
  }

  double _pixelsToMeters(double pixels) =>
      (pixels / Path2Painter.scale) / widget.fieldImage.pixelsPerMeter;

  static bool _samePose(Pose2d first, Pose2d second) {
    return first.translation == second.translation &&
        first.rotation == second.rotation;
  }
}

class _StartingPoseSnapshot {
  final Pose2d pose;
  final bool initialized;

  const _StartingPoseSnapshot(this.pose, this.initialized);
}
