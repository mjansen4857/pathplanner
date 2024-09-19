import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/trajectory/auto_simulator.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/motor_torque_curve.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
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
  final List<ChoreoPath> autoChoreoPaths;
  final List<String> allPathNames;
  final VoidCallback? onAutoChanged;
  final FieldImage fieldImage;
  final ChangeStack undoStack;

  const SplitAutoEditor({
    required this.prefs,
    required this.auto,
    required this.autoPaths,
    required this.autoChoreoPaths,
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
  PathPlannerTrajectory? _simPath;
  bool _paused = false;

  late AnimationController _previewController;
  late bool _holonomicMode;

  @override
  void initState() {
    super.initState();

    _previewController = AnimationController(vsync: this);

    _treeOnRight =
        widget.prefs.getBool(PrefsKeys.treeOnRight) ?? Defaults.treeOnRight;
    _holonomicMode =
        widget.prefs.getBool(PrefsKeys.holonomicMode) ?? Defaults.holonomicMode;

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
                            simulatedPath: _simPath,
                            animation: _previewController.view,
                            previewColor: colorScheme.primary,
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
                  totalPathTime: _simPath?.states.last.timeSeconds ?? 1.0,
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
                    autoRuntime: _simPath?.states.last.timeSeconds,
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
                  totalPathTime: _simPath?.states.last.timeSeconds ?? 1.0,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Marked as async so it can run from initState
  void _simulateAuto() async {
    if (widget.autoPaths.isEmpty) {
      setState(() {
        _simPath = null;
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
      num halfWheelbase = (widget.prefs.getDouble(PrefsKeys.robotWheelbase) ??
              Defaults.robotWheelbase) /
          2;
      num halfTrackwidth = (widget.prefs.getDouble(PrefsKeys.robotTrackwidth) ??
              Defaults.robotTrackwidth) /
          2;
      List<Translation2d> moduleLocations = _holonomicMode
          ? [
              Translation2d(x: halfWheelbase, y: halfTrackwidth),
              Translation2d(x: halfWheelbase, y: -halfTrackwidth),
              Translation2d(x: -halfWheelbase, y: halfTrackwidth),
              Translation2d(x: -halfWheelbase, y: -halfTrackwidth),
            ]
          : [
              Translation2d(x: 0, y: halfTrackwidth),
              Translation2d(x: 0, y: -halfTrackwidth),
            ];

      try {
        simPath = AutoSimulator.simulateAuto(
          widget.autoPaths,
          RobotConfig(
            massKG: widget.prefs.getDouble(PrefsKeys.robotMass) ??
                Defaults.robotMass,
            moi:
                widget.prefs.getDouble(PrefsKeys.robotMOI) ?? Defaults.robotMOI,
            moduleConfig: ModuleConfig(
              wheelRadiusMeters:
                  widget.prefs.getDouble(PrefsKeys.driveWheelRadius) ??
                      Defaults.driveWheelRadius,
              driveGearing: widget.prefs.getDouble(PrefsKeys.driveGearing) ??
                  Defaults.driveGearing,
              maxDriveVelocityRPM:
                  widget.prefs.getDouble(PrefsKeys.maxDriveRPM) ??
                      Defaults.maxDriveRPM,
              driveMotorTorqueCurve: MotorTorqueCurve.fromString(
                  widget.prefs.getString(PrefsKeys.torqueCurve) ??
                      Defaults.torqueCurve),
              wheelCOF: widget.prefs.getDouble(PrefsKeys.wheelCOF) ??
                  Defaults.wheelCOF,
            ),
            moduleLocations: moduleLocations,
            holonomic: _holonomicMode,
          ),
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
        _simPath = simPath;
      });

      if (!_paused) {
        _previewController.stop();
        _previewController.reset();
        _previewController.duration = Duration(
            milliseconds: (simPath.states.last.timeSeconds * 1000).toInt());
        _previewController.repeat();
      }
    } else {
      // Trajectory failed to generate. Notify the user
      Log.warning(
          'Failed to generate trajectory for auto: ${widget.auto.name}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to generate trajectory for ${widget.auto.name}. Try adjusting the path shape or the positions of rotation targets.',
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
