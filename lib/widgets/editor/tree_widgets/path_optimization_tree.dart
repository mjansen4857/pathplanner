import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/path_optimizer.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class PathOptimizationTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ValueChanged<PathPlannerPath?>? onUpdate;
  final ChangeStack undoStack;
  final SharedPreferences prefs;
  final Size fieldSizeMeters;

  const PathOptimizationTree({
    super.key,
    required this.path,
    this.onPathChanged,
    this.onUpdate,
    required this.undoStack,
    required this.prefs,
    required this.fieldSizeMeters,
  });

  @override
  State<PathOptimizationTree> createState() => _PathOptimizationTreeState();
}

class _PathOptimizationTreeState extends State<PathOptimizationTree> {
  OptimizationResult? _currentResult;
  bool _running = false;

  late final Size _robotSize;

  @override
  void initState() {
    super.initState();

    var width =
        widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth;
    var length =
        widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength;
    _robotSize = Size(width, length);
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return TreeCardNode(
      title: const Text('Path Optimizer'),
      leading: const Icon(Icons.query_stats),
      initiallyExpanded: widget.path.pathOptimizationExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          widget.path.pathOptimizationExpanded = value;
        }
      },
      elevation: 1.0,
      children: [
        Center(
          child: Text(
            'Optimized Runtime: ${(_currentResult?.runtime ?? 0.0).toStringAsFixed(2)}s',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Optimize'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  elevation: 4.0,
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _running ? null : _runOptimization,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Discard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                  elevation: 4.0,
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (_running || _currentResult == null)
                    ? null
                    : _discardOptimization,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: colorScheme.onSecondaryContainer,
                  elevation: 4.0,
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (_running || _currentResult == null)
                    ? null
                    : _acceptOptimization,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: LinearProgressIndicator(
            value:
                (_currentResult?.generation ?? 0) / PathOptimizer.generations,
          ),
        ),
      ],
    );
  }

  void _runOptimization() async {
    setState(() {
      _running = true;
      _currentResult = null;
    });

    RobotConfig config = RobotConfig.fromPrefs(widget.prefs);

    widget.onUpdate?.call(_currentResult?.path);

    final result = await PathOptimizer.optimizePath(
      widget.path,
      config,
      widget.fieldSizeMeters,
      _robotSize,
      onUpdate: (result) {
        if (mounted) {
          setState(() {
            _currentResult = result;
            widget.onUpdate?.call(_currentResult?.path);
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _running = false;
        _currentResult = result;
      });

      widget.onUpdate?.call(_currentResult?.path);
    }
  }

  void _discardOptimization() {
    setState(() {
      _currentResult = null;
    });
    widget.onUpdate?.call(_currentResult?.path);
  }

  void _acceptOptimization() {
    if (_currentResult == null) return;

    final points =
        PathPlannerPath.cloneWaypoints(_currentResult!.path.waypoints);

    widget.undoStack.add(Change(
      PathPlannerPath.cloneWaypoints(widget.path.waypoints),
      () {
        setState(() {
          _currentResult = null;
        });
        widget.onUpdate?.call(_currentResult?.path);

        widget.path.waypoints = points;
        widget.onPathChanged?.call();
      },
      (oldValue) {
        setState(() {
          _currentResult = null;
        });
        widget.onUpdate?.call(_currentResult?.path);

        widget.path.waypoints = PathPlannerPath.cloneWaypoints(oldValue);
        widget.onPathChanged?.call();
      },
    ));
  }
}
