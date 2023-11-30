import 'dart:math';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/simulator/trajectory_generator.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/path_painter.dart';
import 'package:pathplanner/widgets/editor/preview_seekbar.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/auto_tree.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class SplitAutoEditor extends StatefulWidget {
  final SharedPreferences prefs;
  final PathPlannerAuto auto;
  final List<PathPlannerPath> autoPaths;
  final List<String> allPathNames;
  final VoidCallback? onAutoChanged;
  final FieldImage fieldImage;
  final ChangeStack undoStack;

  const SplitAutoEditor({
    required this.prefs,
    required this.auto,
    required this.autoPaths,
    required this.allPathNames,
    required this.fieldImage,
    required this.undoStack,
    this.onAutoChanged,
    super.key,
  });

  @override
  State<SplitAutoEditor> createState() => _SplitAutoEditorState();
}

class _SplitAutoEditorState extends State<SplitAutoEditor>
    with SingleTickerProviderStateMixin {
  final MultiSplitViewController _controller = MultiSplitViewController();
  String? _hoveredPath;
  late bool _treeOnRight;
  bool _draggingStartPos = false;
  bool _draggingStartRot = false;
  Pose2d? _dragOldValue;
  Trajectory? _simPath;
  bool _paused = false;

  late Size _robotSize;
  late AnimationController _previewController;

  @override
  void initState() {
    super.initState();

    _previewController = AnimationController(vsync: this);

    _treeOnRight =
        widget.prefs.getBool(PrefsKeys.treeOnRight) ?? Defaults.treeOnRight;

    var width =
        widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth;
    var length =
        widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength;
    _robotSize = Size(width, length);

    double treeWeight = widget.prefs.getDouble(PrefsKeys.editorTreeWeight) ??
        Defaults.editorTreeWeight;
    _controller.areas = [
      Area(
        weight: _treeOnRight ? (1.0 - treeWeight) : treeWeight,
        minimalWeight: 0.3,
      ),
      Area(
        weight: _treeOnRight ? treeWeight : (1.0 - treeWeight),
        minimalWeight: 0.3,
      ),
    ];

    _simulateAuto();
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
              onPanStart: (details) {
                if (widget.auto.startingPose != null) {
                  double xPos = _xPixelsToMeters(details.localPosition.dx);
                  double yPos = _yPixelsToMeters(details.localPosition.dy);

                  double posRadius = _pixelsToMeters(
                      PathPainterUtil.uiPointSizeToPixels(
                          25, PathPainter.scale, widget.fieldImage));
                  if (pow(xPos - widget.auto.startingPose!.position.x, 2) +
                          pow(yPos - widget.auto.startingPose!.position.y, 2) <
                      pow(posRadius, 2)) {
                    _draggingStartPos = true;
                    _dragOldValue = widget.auto.startingPose!.clone();
                  } else {
                    double rotRadius = _pixelsToMeters(
                        PathPainterUtil.uiPointSizeToPixels(
                            15, PathPainter.scale, widget.fieldImage));
                    num angleRadians =
                        widget.auto.startingPose!.rotation / 180.0 * pi;
                    num dotX = widget.auto.startingPose!.position.x +
                        (_robotSize.height / 2 * cos(angleRadians));
                    num dotY = widget.auto.startingPose!.position.y +
                        (_robotSize.height / 2 * sin(angleRadians));
                    if (pow(xPos - dotX, 2) + pow(yPos - dotY, 2) <
                        pow(rotRadius, 2)) {
                      _draggingStartRot = true;
                      _dragOldValue = widget.auto.startingPose!.clone();
                    }
                  }
                }
              },
              onPanUpdate: (details) {
                if (_draggingStartPos && widget.auto.startingPose != null) {
                  num targetX = _xPixelsToMeters(min(
                      88 +
                          (widget.fieldImage.defaultSize.width *
                              PathPainter.scale),
                      max(8, details.localPosition.dx)));
                  num targetY = _yPixelsToMeters(min(
                      88 +
                          (widget.fieldImage.defaultSize.height *
                              PathPainter.scale),
                      max(8, details.localPosition.dy)));

                  if (widget.prefs.getBool(PrefsKeys.snapToGuidelines) ??
                      Defaults.snapToGuidelines) {
                    if (widget.autoPaths.isNotEmpty &&
                        (widget.autoPaths[0].waypoints[0].anchor.x - targetX)
                                .abs() <
                            0.25) {
                      targetX = widget.autoPaths[0].waypoints[0].anchor.x;
                    }
                    if (widget.autoPaths.isNotEmpty &&
                        (widget.autoPaths[0].waypoints[0].anchor.y - targetY)
                                .abs() <
                            0.25) {
                      targetY = widget.autoPaths[0].waypoints[0].anchor.y;
                    }
                  }

                  setState(() {
                    widget.auto.startingPose!.position =
                        Point(targetX, targetY);
                  });
                } else if (_draggingStartRot &&
                    widget.auto.startingPose != null) {
                  double x = _xPixelsToMeters(details.localPosition.dx);
                  double y = _yPixelsToMeters(details.localPosition.dy);
                  num rotation = atan2(y - widget.auto.startingPose!.position.y,
                      x - widget.auto.startingPose!.position.x);
                  num rotationDeg = (rotation * 180 / pi);

                  setState(() {
                    widget.auto.startingPose!.rotation = rotationDeg;
                  });
                }
              },
              onPanEnd: (details) {
                if (widget.auto.startingPose != null &&
                    (_draggingStartPos || _draggingStartRot)) {
                  Pose2d dragEnd = widget.auto.startingPose!.clone();
                  widget.undoStack.add(Change(
                    _dragOldValue,
                    () {
                      widget.auto.startingPose = dragEnd.clone();
                      widget.onAutoChanged?.call();
                      _simulateAuto();
                    },
                    (oldValue) {
                      widget.auto.startingPose = oldValue!.clone();
                      widget.onAutoChanged?.call();
                      _simulateAuto();
                    },
                  ));
                  _draggingStartPos = false;
                  _draggingStartRot = false;
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Stack(
                  children: [
                    widget.fieldImage.getWidget(),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: PathPainter(
                          paths: widget.autoPaths,
                          simple: true,
                          hideOtherPathsOnHover: widget.prefs
                                  .getBool(PrefsKeys.hidePathsOnHover) ??
                              Defaults.hidePathsOnHover,
                          hoveredPath: _hoveredPath,
                          fieldImage: widget.fieldImage,
                          startingPose: widget.auto.startingPose,
                          simulatedPath: _simPath,
                          animation: _previewController.view,
                          previewColor: colorScheme.primary,
                          prefs: widget.prefs,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        MultiSplitViewTheme(
          data: MultiSplitViewThemeData(
            dividerPainter: DividerPainters.grooved1(
              color: colorScheme.surfaceVariant,
              highlightedColor: colorScheme.primary,
            ),
          ),
          child: MultiSplitView(
            axis: Axis.horizontal,
            controller: _controller,
            onWeightChange: () {
              double? newWeight = _treeOnRight
                  ? _controller.areas[1].weight
                  : _controller.areas[0].weight;
              widget.prefs
                  .setDouble(PrefsKeys.editorTreeWeight, newWeight ?? 0.5);
            },
            children: [
              if (_treeOnRight)
                PreviewSeekbar(
                  previewController: _previewController,
                  onPauseStateChanged: (value) => _paused = value,
                  totalPathTime: _simPath?.states.last.time ?? 1.0,
                ),
              Card(
                margin: const EdgeInsets.all(0),
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft:
                        _treeOnRight ? const Radius.circular(12) : Radius.zero,
                    topRight:
                        _treeOnRight ? Radius.zero : const Radius.circular(12),
                    bottomLeft:
                        _treeOnRight ? const Radius.circular(12) : Radius.zero,
                    bottomRight:
                        _treeOnRight ? Radius.zero : const Radius.circular(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AutoTree(
                    auto: widget.auto,
                    autoRuntime: _simPath?.states.last.time,
                    allPathNames: widget.allPathNames,
                    onPathHovered: (value) {
                      setState(() {
                        _hoveredPath = value;
                      });
                    },
                    onAutoChanged: () {
                      widget.onAutoChanged?.call();
                      // Delay this because it needs the parent widget to rebuild first
                      Future.delayed(const Duration(milliseconds: 100))
                          .then((_) {
                        _simulateAuto();
                      });
                    },
                    onSideSwapped: () => setState(() {
                      _treeOnRight = !_treeOnRight;
                      widget.prefs.setBool(PrefsKeys.treeOnRight, _treeOnRight);
                      _controller.areas = _controller.areas.reversed.toList();
                    }),
                    undoStack: widget.undoStack,
                  ),
                ),
              ),
              if (!_treeOnRight)
                PreviewSeekbar(
                  previewController: _previewController,
                  onPauseStateChanged: (value) => _paused = value,
                  totalPathTime: _simPath?.states.last.time ?? 1.0,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Marked as async so it can run from initState
  void _simulateAuto() async {
    Trajectory? simPath;

    num maxModuleSpeed = widget.prefs.getDouble(PrefsKeys.maxModuleSpeed) ??
        Defaults.maxModuleSpeed;
    num radius = sqrt(pow(_robotSize.width, 2) + pow(_robotSize.height, 2)) -
        0.1; // Assuming ~3in thick bumpers

    try {
      simPath = TrajectoryGenerator.simulateAuto(
          widget.autoPaths, widget.auto.startingPose, maxModuleSpeed, radius);
    } catch (err) {
      Log.error('Failed to simulate auto', err);
    }

    if (simPath != null &&
        simPath.states.last.time.isFinite &&
        !simPath.states.last.time.isNaN) {
      setState(() {
        _simPath = simPath;
      });

      if (!_paused) {
        _previewController.stop();
        _previewController.reset();
        _previewController.duration =
            Duration(milliseconds: (simPath.states.last.time * 1000).toInt());
        _previewController.repeat();
      }
    }
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels - 48) / PathPainter.scale) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _yPixelsToMeters(double pixels) {
    return (widget.fieldImage.defaultSize.height -
            ((pixels - 48) / PathPainter.scale)) /
        widget.fieldImage.pixelsPerMeter;
  }

  double _pixelsToMeters(double pixels) {
    return (pixels / PathPainter.scale) / widget.fieldImage.pixelsPerMeter;
  }
}
