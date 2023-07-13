import 'package:flutter/material.dart';
import 'package:flutter_simple_treeview/flutter_simple_treeview.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';

class PathTree extends StatefulWidget {
  final PathPlannerPath path;

  const PathTree({
    super.key,
    required this.path,
  });

  @override
  State<PathTree> createState() => _PathTreeState();
}

class _PathTreeState extends State<PathTree> {
  List<Waypoint> get waypoints => widget.path.waypoints;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: TreeView(
        nodes: [
          TreeNode(
            content: const Text('Path'),
            children: [
              for (int w = 0; w < waypoints.length; w++) _buildWaypointNode(w),
              TreeNode(
                content: const Text('Goal End Velocity'),
              ),
              TreeNode(
                content: const Text('Global Constraints'),
                children: [
                  TreeNode(
                    content:
                        const Text('Max Velocity          Max Acceleration'),
                  ),
                  TreeNode(
                    content: const Text(
                        'Max Angular Vel          Max Angular Accel'),
                  ),
                ],
              ),
              TreeNode(
                content: const Text('Is Reversed'),
              ),
            ],
          ),
          TreeNode(
            content: const Text('Rotation Targets'),
            children: [
              TreeNode(
                content: const Text(
                    'Rotation Target 0          Position          Rotation'),
              ),
              TreeNode(
                content: const Text('Stop Point 0          Rotation'),
              ),
              TreeNode(
                content: const Text('End Point          Rotation'),
              ),
            ],
          ),
          TreeNode(
            content: const Text('Event Markers'),
            children: [
              TreeNode(
                content: const Text('Event Marker 0'),
                children: [
                  TreeNode(
                    content:
                        const Text('Position          Min Trigger Distance'),
                  ),
                  TreeNode(
                    content: const Text('Nested Commands'),
                  ),
                ],
              ),
              TreeNode(
                content: const Text('Custom Name'),
                children: [
                  TreeNode(
                    content:
                        const Text('Position          Min Trigger Distance'),
                  ),
                  TreeNode(
                    content: const Text('Nested Commands'),
                  ),
                ],
              ),
            ],
          ),
          TreeNode(
            content: const Text('Constraint Zones'),
            children: [
              TreeNode(
                content: const Text('Constraint Zone 0'),
                children: [
                  TreeNode(
                    content: const Text('Range Slider'),
                  ),
                  TreeNode(
                    content:
                        const Text('Max Velocity          Max Acceleration'),
                  ),
                  TreeNode(
                    content: const Text(
                        'Max Angular Vel          Max Angular Accel'),
                  ),
                ],
              ),
              TreeNode(
                content: const Text('Custom Name'),
                children: [
                  TreeNode(
                    content: const Text('Range Slider'),
                  ),
                  TreeNode(
                    content:
                        const Text('Max Velocity          Max Acceleration'),
                  ),
                  TreeNode(
                    content: const Text(
                        'Max Angular Vel          Max Angular Accel'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  TreeNode _buildWaypointNode(int waypointIdx) {
    String name = 'Waypoint $waypointIdx';
    if (waypointIdx == 0) {
      name = 'Start Point';
    } else if (waypointIdx == waypoints.length - 1) {
      name = 'End Point';
    }

    bool isStopPoint = (waypointIdx == 0 || waypointIdx == waypoints.length - 1)
        ? true
        : waypoints[waypointIdx].isStopPoint;

    return TreeNode(
      content: Text(name),
      children: [
        // Top row
        TreeNode(
          content: const Text('X Pos          Y Pos          Heading'),
        ),
        // Mid row
        if (waypointIdx == 0)
          TreeNode(
            content: const Text('Leading Control Length'),
          ),
        if (waypointIdx == waypoints.length - 1)
          TreeNode(
            content: const Text('Trailing Control Length'),
          ),
        if (waypointIdx != 0 && waypointIdx != waypoints.length - 1)
          TreeNode(
            content: const Text(
                'Trailing Control Length          Leading Control Length'),
          ),
        if (waypointIdx != 0 && waypointIdx != waypoints.length - 1)
          TreeNode(
            content: const Text('Is Reversal          Is Stop Point'),
          ),
        // Bottom row
        if (isStopPoint)
          TreeNode(
            content: const Text('Stop Event'),
            children: [
              TreeNode(
                content: const Text('Nested Commands'),
              ),
            ],
          ),
      ],
    );
  }
}
