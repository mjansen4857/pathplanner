import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/path_optimizer.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
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
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  label: const Text('Optimize'),
                  icon: const Icon(Icons.query_stats),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    elevation: 4.0,
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _running
                      ? null
                      : () async {
                          RobotConfig config =
                              RobotConfig.fromPrefs(widget.prefs);

                          setState(() {
                            _running = true;
                            _currentResult = null;
                          });

                          widget.onUpdate?.call(_currentResult?.path);

                          final result = await PathOptimizer.optimizePath(
                              widget.path, config,
                              onUpdate: (result) => setState(() {
                                    _currentResult = result;
                                    widget.onUpdate?.call(_currentResult?.path);
                                  }));

                          print(
                              'test: ${PathPlannerTrajectory(path: result.path, robotConfig: config).getTotalTimeSeconds()}');
                          print(result.path.rotationTargets.length);

                          setState(() {
                            _running = false;
                            _currentResult = result;
                          });

                          widget.onUpdate?.call(_currentResult?.path);
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  label: const Text('Discard'),
                  icon: const Icon(Icons.close),
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
                      : () {
                          setState(() {
                            _currentResult = null;
                          });
                          widget.onUpdate?.call(_currentResult?.path);
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  label: const Text('Accept'),
                  icon: const Icon(Icons.check),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: colorScheme.onSurface,
                    elevation: 4.0,
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: (_running || _currentResult == null)
                      ? null
                      : () {
                          if (_currentResult == null) {
                            return;
                          }

                          final points = PathPlannerPath.cloneWaypoints(
                              _currentResult!.path.waypoints);

                          setState(() {
                            _currentResult = null;
                          });
                          widget.onUpdate?.call(_currentResult?.path);

                          widget.undoStack.add(Change(
                            PathPlannerPath.cloneWaypoints(
                                widget.path.waypoints),
                            () {
                              widget.path.waypoints = points;
                              widget.onPathChanged?.call();
                            },
                            (oldValue) {
                              widget.path.waypoints =
                                  PathPlannerPath.cloneWaypoints(oldValue);
                              widget.onPathChanged?.call();
                            },
                          ));
                        },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: LinearProgressIndicator(
            value:
                (_currentResult?.generation ?? 0) / PathOptimizer.generations,
          ),
        ),
      ],
    );
  }
}
