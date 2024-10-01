import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/path_optimizer.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class PathOptimizationTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ValueChanged<PathPlannerPath?>? onUpdate;
  final ChangeStack undoStack;
  final SharedPreferences prefs;

  const PathOptimizationTree({
    super.key,
    required this.path,
    this.onPathChanged,
    this.onUpdate,
    required this.undoStack,
    required this.prefs,
  });

  @override
  State<PathOptimizationTree> createState() => _PathOptimizationTreeState();
}

class _PathOptimizationTreeState extends State<PathOptimizationTree> {
  OptimizationResult? _currentResult;
  bool _running = false;

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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optimized Runtime: ${(_currentResult?.runtime ?? 0.0).toStringAsFixed(2)}s',
                style: Theme.of(context).textTheme.bodyLarge,
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
                      ),
                      onPressed: (_running || _currentResult == null)
                          ? null
                          : _acceptOptimization,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_currentResult?.generation ?? 0) /
                    PathOptimizer.generations,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _runOptimization() async {
    RobotConfig config = RobotConfig.fromPrefs(widget.prefs);

    setState(() {
      _running = true;
      _currentResult = null;
    });

    widget.onUpdate?.call(_currentResult?.path);

    final result = await PathOptimizer.optimizePath(
      widget.path,
      config,
      onUpdate: (result) => setState(() {
        _currentResult = result;
        widget.onUpdate?.call(_currentResult?.path);
      }),
    );

    setState(() {
      _running = false;
      _currentResult = result;
    });

    widget.onUpdate?.call(_currentResult?.path);
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
