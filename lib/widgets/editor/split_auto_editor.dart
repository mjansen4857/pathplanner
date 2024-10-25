import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/trajectory/auto_simulator.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/dialogs/trajectory_render_dialog.dart';
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
  final List<ChoreoPath> autoChoreoPaths;
  final List<String> allPathNames;
  final VoidCallback? onAutoChanged;
  final FieldImage fieldImage;
  final ChangeStack undoStack;
  final Function(String?)? onEditPathPressed;

  const SplitAutoEditor({
    required this.prefs,
    required this.auto,
    required this.autoPaths,
    required this.autoChoreoPaths,
    required this.allPathNames,
    required this.fieldImage,
    required this.undoStack,
    this.onAutoChanged,
    this.onEditPathPressed,
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
  PathPlannerTrajectory? _simTraj;
  bool _paused = false;

  late AnimationController _previewController;

  @override
  void initState() {
    super.initState();

    _previewController = AnimationController(vsync: this);

    _treeOnRight =
        widget.prefs.getBool(PrefsKeys.treeOnRight) ?? Defaults.treeOnRight;

    double treeWeight = widget.prefs.getDouble(PrefsKeys.editorTreeWeight) ??
        Defaults.editorTreeWeight;
    _controller.areas = [
      Area(
        weight: _treeOnRight ? (1.0 - treeWeight) : treeWeight,
        minimalWeight: 0.4,
      ),
      Area(
        weight: _treeOnRight ? treeWeight : (1.0 - treeWeight),
        minimalWeight: 0.4,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) => _simulateAuto());
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
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Stack(
                children: [
                  widget.fieldImage.getWidget(),
                  Positioned.fill(
                    child: CustomPaint(
                        painter: PathPainter(
                            colorScheme: colorScheme,
                            paths: widget.autoPaths,
                            choreoPaths: widget.autoChoreoPaths,
                            simple: true,
                            hideOtherPathsOnHover: widget.prefs
                                    .getBool(PrefsKeys.hidePathsOnHover) ??
                                Defaults.hidePathsOnHover,
                            hoveredPath: _hoveredPath,
                            fieldImage: widget.fieldImage,
                            simulatedPath: _simTraj,
                            animation: _previewController.view,
                            prefs: widget.prefs)),
                  ),
                ],
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
                  totalPathTime: _simTraj?.states.last.timeSeconds ?? 1.0,
                ),
              Card(
                margin: const EdgeInsets.all(0),
                elevation: 4.0,
                color: colorScheme.surface,
                surfaceTintColor: colorScheme.surfaceTint,
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
                    autoRuntime: _simTraj?.states.last.timeSeconds,
                    allPathNames: widget.allPathNames,
                    onRenderAuto: () {
                      if (_simTraj != null) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return TrajectoryRenderDialog(
                                fieldImage: widget.fieldImage,
                                prefs: widget.prefs,
                                trajectory: _simTraj!,
                              );
                            });
                      }
                    },
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
                    onEditPathPressed: widget.onEditPathPressed,
                  ),
                ),
              ),
              if (!_treeOnRight)
                PreviewSeekbar(
                  previewController: _previewController,
                  onPauseStateChanged: (value) => _paused = value,
                  totalPathTime: _simTraj?.states.last.timeSeconds ?? 1.0,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Marked as async so it can run from initState
  void _simulateAuto() async {
    if (widget.autoPaths.isEmpty && widget.autoChoreoPaths.isEmpty) {
      setState(() {
        _simTraj = null;
      });

      _previewController.stop();
      _previewController.reset();

      return;
    }

    PathPlannerTrajectory? simPath;

    if (widget.auto.choreoAuto) {
      List<TrajectoryState> allStates = [];
      num timeOffset = 0.0;

      for (ChoreoPath p in widget.autoChoreoPaths) {
        for (TrajectoryState s in p.trajectory.states) {
          allStates.add(s.copyWithTime(s.timeSeconds + timeOffset));
        }

        if (allStates.isNotEmpty) {
          timeOffset = allStates.last.timeSeconds;
        }
      }

      if (allStates.isNotEmpty) {
        simPath = PathPlannerTrajectory.fromStates(allStates);
      }
    } else {
      RobotConfig config = RobotConfig.fromPrefs(widget.prefs);

      try {
        simPath = AutoSimulator.simulateAuto(
          widget.autoPaths,
          config,
        );
        if (!(simPath?.getTotalTimeSeconds().isFinite ?? false)) {
          simPath = null;
        }
      } catch (err) {
        Log.error('Failed to simulate auto', err);
      }
    }

    if (simPath != null &&
        simPath.states.last.timeSeconds.isFinite &&
        !simPath.states.last.timeSeconds.isNaN) {
      setState(() {
        _simTraj = simPath;
      });

      if (!_paused) {
        _previewController.stop();
        _previewController.reset();
        _previewController.duration = Duration(
            milliseconds: (simPath.states.last.timeSeconds * 1000).toInt());
        _previewController.repeat();
      } else {
        double prevTime = _previewController.value *
            (_previewController.duration!.inMilliseconds / 1000.0);
        _previewController.duration = Duration(
            milliseconds: (simPath.states.last.timeSeconds * 1000).toInt());
        double newPos = prevTime / simPath.states.last.timeSeconds;
        _previewController.forward(from: newPos);
        _previewController.stop();
      }
    } else {
      // Trajectory failed to generate. Notify the user
      Log.warning(
          'Failed to generate trajectory for auto: ${widget.auto.name}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to generate trajectory for ${widget.auto.name}. Please open an issue on the pathplanner github and include the failing path file.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer),
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Theme.of(context).colorScheme.onErrorContainer,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }
}
