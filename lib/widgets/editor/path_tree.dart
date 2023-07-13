import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_simple_treeview/flutter_simple_treeview.dart';
import 'package:function_tree/function_tree.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/editor/tree_card_node.dart';

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
      child: Column(
        children: [
          TreeCardNode(
            title: const Text('Waypoints'),
            elevation: 1.0,
            children: [
              for (int w = 0; w < waypoints.length; w++)
                _buildWaypointTreeNode(w),
            ],
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
    );
  }

  Widget _buildWaypointTreeNode(int waypointIdx) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    String name = 'Waypoint $waypointIdx';
    if (waypointIdx == 0) {
      name = 'Start Point';
    } else if (waypointIdx == waypoints.length - 1) {
      name = 'End Point';
    }

    bool isStopPoint = (waypointIdx == 0 || waypointIdx == waypoints.length - 1)
        ? true
        : waypoints[waypointIdx].isStopPoint;

    return TreeCardNode(
      title: Row(
        children: [
          Text(name),
          Expanded(child: Container()),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.delete_forever),
            color: colorScheme.error,
          ),
        ],
      ),
      elevation: 4.0,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: _buildTextField(
                    _getController(
                        waypoints[waypointIdx].anchor.x.toStringAsFixed(2)),
                    'X Position (M)'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                    _getController(
                        waypoints[waypointIdx].anchor.y.toStringAsFixed(2)),
                    'Y Position (M)'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                    _getController(waypoints[waypointIdx]
                        .getHeadingDegrees()
                        .toStringAsFixed(2)),
                    'Heading (Deg)'),
              ),
            ],
          ),
        ),
        if (waypointIdx == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildTextField(
                        _getController(waypoints[waypointIdx]
                            .getNextControlLength()
                            .toStringAsFixed(2)),
                        'Next Control Length (M)'),
                  ),
                ),
              ],
            ),
          ),
        if (waypointIdx == waypoints.length - 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildTextField(
                        _getController(waypoints[waypointIdx]
                            .getPrevControlLength()
                            .toStringAsFixed(2)),
                        'Previous Control Length (M)'),
                  ),
                ),
              ],
            ),
          ),
        if (waypointIdx != 0 && waypointIdx != waypoints.length - 1)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        _getController(waypoints[waypointIdx]
                            .getPrevControlLength()
                            .toStringAsFixed(2)),
                        'Previous Control Length (M)'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTextField(
                        _getController(waypoints[waypointIdx]
                            .getNextControlLength()
                            .toStringAsFixed(2)),
                        'Next Control Length (M)'),
                  ),
                ],
              ),
            ),
          ),
        if (waypointIdx != 0 && waypointIdx != waypoints.length - 1)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 5.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Is Locked'),
                  selected: waypoints[waypointIdx].isLocked,
                  onSelected: (selected) {
                    setState(() {
                      waypoints[waypointIdx].isLocked = selected;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Is Reversal'),
                  selected: waypoints[waypointIdx].isReversal,
                  onSelected: (selected) {},
                ),
                FilterChip(
                  label: const Text('Is Stop Point'),
                  selected: waypoints[waypointIdx].isStopPoint,
                  onSelected: (selected) {},
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController? controller, String label,
      {ValueChanged? onSubmitted}) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 42,
      child: TextField(
        onSubmitted: (val) {
          if (onSubmitted != null) {
            if (val.isEmpty) {
              onSubmitted(null);
            } else {
              num parsed = val.interpret();
              onSubmitted(parsed);
            }
          }
          FocusScopeNode currentScope = FocusScope.of(context);
          if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
            FocusManager.instance.primaryFocus!.unfocus();
          }
        },
        controller: controller,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(r'(^(-?)\d*\.?\d*)([+/\*\-](-?)\d*\.?\d*)*')),
        ],
        style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  TextEditingController _getController(String text) {
    return TextEditingController(text: text)
      ..selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
  }
}
