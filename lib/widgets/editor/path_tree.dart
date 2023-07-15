import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/global_constraints_tree.dart';
import 'package:pathplanner/widgets/editor/tree_card_node.dart';
import 'package:pathplanner/widgets/editor/waypoints_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';

class PathTree extends StatefulWidget {
  final PathPlannerPath path;
  final ValueChanged<int?>? onWaypointHovered;
  final ValueChanged<int?>? onWaypointSelected;
  final ValueChanged<int>? onWaypointDeleted;
  final VoidCallback? onSideSwapped;
  final VoidCallback? onPathChanged;
  final WaypointsTreeController? waypointsTreeController;
  final int? initiallySelectedWaypoint;

  const PathTree({
    super.key,
    required this.path,
    this.onWaypointHovered,
    this.onSideSwapped,
    this.onPathChanged,
    this.onWaypointSelected,
    this.waypointsTreeController,
    this.initiallySelectedWaypoint,
    this.onWaypointDeleted,
  });

  @override
  State<PathTree> createState() => _PathTreeState();
}

class _PathTreeState extends State<PathTree> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              const Text(
                'Simulated Driving Time: X.XXs',
                style: TextStyle(fontSize: 18),
              ),
              Expanded(child: Container()),
              Tooltip(
                message: 'Move to Other Side',
                waitDuration: const Duration(seconds: 1),
                child: IconButton(
                  onPressed: widget.onSideSwapped,
                  icon: const Icon(Icons.swap_horiz),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4.0),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                WaypointsTree(
                  key: ValueKey(widget.path.waypoints.length),
                  onWaypointDeleted: widget.onWaypointDeleted,
                  initialSelectedWaypoint: widget.initiallySelectedWaypoint,
                  controller: widget.waypointsTreeController,
                  path: widget.path,
                  onWaypointHovered: widget.onWaypointHovered,
                  onWaypointSelected: widget.onWaypointSelected,
                  onPathChanged: widget.onPathChanged,
                ),
                GlobalConstraintsTree(
                  path: widget.path,
                  onPathChanged: widget.onPathChanged,
                ),
                TreeCardNode(
                  title: const Text('Goal End State'),
                  initiallyExpanded: false,
                  elevation: 1.0,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: NumberTextField(
                              initialText: 0.toStringAsFixed(2),
                              label: 'Velocity (M/S)',
                              onSubmitted: (value) {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NumberTextField(
                              initialText: 0.toStringAsFixed(2),
                              label: 'Rotation (Deg)',
                              onSubmitted: (value) {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const TreeCardNode(
                  title: Text('Event Markers'),
                  initiallyExpanded: false,
                  elevation: 1.0,
                  children: [],
                ),
                const TreeCardNode(
                  title: Text('Constraint Zones'),
                  initiallyExpanded: false,
                  elevation: 1.0,
                  children: [],
                ),
                // TreeView(
                //   indent: 16,
                //   nodes: [
                //     TreeNode(
                //       content: const Text('Path'),
                //       children: [
                //         for (int w = 0; w < waypoints.length; w++)
                //           _buildWaypointNode(w),
                //         TreeNode(
                //           content: const Text('Goal End Velocity'),
                //         ),
                //         TreeNode(
                //           content: const Text('Global Constraints'),
                //           children: [
                //             TreeNode(
                //               content: const Text(
                //                   'Max Velocity          Max Acceleration'),
                //             ),
                //             TreeNode(
                //               content: const Text(
                //                   'Max Angular Vel          Max Angular Accel'),
                //             ),
                //           ],
                //         ),
                //         TreeNode(
                //           content: const Text('Is Reversed'),
                //         ),
                //       ],
                //     ),
                //     TreeNode(
                //       content: const Text('Rotation Targets'),
                //       children: [
                //         TreeNode(
                //           content: const Text(
                //               'Rotation Target 0          Position          Rotation'),
                //         ),
                //         TreeNode(
                //           content: const Text('Stop Point 0          Rotation'),
                //         ),
                //         TreeNode(
                //           content: const Text('End Point          Rotation'),
                //         ),
                //       ],
                //     ),
                //     TreeNode(
                //       content: const Text('Event Markers'),
                //       children: [
                //         TreeNode(
                //           content: const Text('Event Marker 0'),
                //           children: [
                //             TreeNode(
                //               content: const Text(
                //                   'Position          Min Trigger Distance'),
                //             ),
                //             TreeNode(
                //               content: const Text('Nested Commands'),
                //             ),
                //           ],
                //         ),
                //         TreeNode(
                //           content: const Text('Custom Name'),
                //           children: [
                //             TreeNode(
                //               content: const Text(
                //                   'Position          Min Trigger Distance'),
                //             ),
                //             TreeNode(
                //               content: const Text('Nested Commands'),
                //             ),
                //           ],
                //         ),
                //       ],
                //     ),
                //     TreeNode(
                //       content: const Text('Constraint Zones'),
                //       children: [
                //         TreeNode(
                //           content: const Text('Constraint Zone 0'),
                //           children: [
                //             TreeNode(
                //               content: const Text('Range Slider'),
                //             ),
                //             TreeNode(
                //               content: const Text(
                //                   'Max Velocity          Max Acceleration'),
                //             ),
                //             TreeNode(
                //               content: const Text(
                //                   'Max Angular Vel          Max Angular Accel'),
                //             ),
                //           ],
                //         ),
                //         TreeNode(
                //           content: const Text('Custom Name'),
                //           children: [
                //             TreeNode(
                //               content: const Text('Range Slider'),
                //             ),
                //             TreeNode(
                //               content: const Text(
                //                   'Max Velocity          Max Acceleration'),
                //             ),
                //             TreeNode(
                //               content: const Text(
                //                   'Max Angular Vel          Max Angular Accel'),
                //             ),
                //           ],
                //         ),
                //       ],
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
