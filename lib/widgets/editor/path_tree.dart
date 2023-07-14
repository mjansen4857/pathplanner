import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_simple_treeview/flutter_simple_treeview.dart';
import 'package:function_tree/function_tree.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/editor/tree_card_node.dart';
import 'package:undo/undo.dart';

class PathTree extends StatefulWidget {
  final PathPlannerPath path;
  final ValueChanged<int?>? onWaypointHover;
  final VoidCallback? onSideSwapped;
  final VoidCallback? onPathChanged;

  const PathTree({
    super.key,
    required this.path,
    this.onWaypointHover,
    this.onSideSwapped,
    this.onPathChanged,
  });

  @override
  State<PathTree> createState() => _PathTreeState();
}

class _PathTreeState extends State<PathTree> {
  List<Waypoint> get waypoints => widget.path.waypoints;

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
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                TreeCardNode(
                  title: const Text('Waypoints'),
                  initiallyExpanded: true,
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
          ),
        ),
      ],
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

    Waypoint waypoint = waypoints[waypointIdx];

    return TreeCardNode(
      onHoverStart: () => widget.onWaypointHover?.call(waypointIdx),
      onHoverEnd: () => widget.onWaypointHover?.call(null),
      elevation: 4.0,
      title: Row(
        children: [
          Text(name),
          Expanded(child: Container()),
          Tooltip(
            message: waypoint.isLocked ? 'Unlock' : 'Lock',
            waitDuration: const Duration(seconds: 1),
            child: IconButton(
              onPressed: () {
                setState(() {
                  waypoint.isLocked = !waypoint.isLocked;
                });
                widget.path.generateAndSavePath();
              },
              icon: Icon(waypoint.isLocked ? Icons.lock : Icons.lock_open,
                  color: colorScheme.onSurface),
            ),
          ),
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.delete_forever),
            color: colorScheme.error,
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _getController(waypoint.anchor.x.toStringAsFixed(2)),
                  'X Position (M)',
                  onSubmitted: (value) {
                    if (value != null) {
                      Waypoint wRef = waypoints[waypointIdx];
                      UndoRedo.addChange(_waypointChange(
                        wRef,
                        () => wRef.move(value, wRef.anchor.y),
                        (oldVal) => wRef.move(oldVal.anchor.x, oldVal.anchor.y),
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  _getController(waypoint.anchor.y.toStringAsFixed(2)),
                  'Y Position (M)',
                  onSubmitted: (value) {
                    if (value != null) {
                      Waypoint wRef = waypoints[waypointIdx];
                      UndoRedo.addChange(_waypointChange(
                        wRef,
                        () => wRef.move(wRef.anchor.x, value),
                        (oldVal) => wRef.move(oldVal.anchor.x, oldVal.anchor.y),
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  _getController(
                      waypoint.getHeadingDegrees().toStringAsFixed(2)),
                  'Heading (Deg)',
                  onSubmitted: (value) {
                    if (value != null) {
                      Waypoint wRef = waypoints[waypointIdx];
                      UndoRedo.addChange(_waypointChange(
                        wRef,
                        () => wRef.setHeading(value),
                        (oldVal) => wRef.setHeading(oldVal.getHeadingDegrees()),
                      ));
                    }
                  },
                ),
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
                      _getController(
                          waypoint.getNextControlLength().toStringAsFixed(2)),
                      'Next Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          UndoRedo.addChange(_waypointChange(
                            wRef,
                            () => wRef.setNextControlLength(value),
                            (oldVal) => wRef.setNextControlLength(
                                oldVal.getNextControlLength()),
                          ));
                        }
                      },
                    ),
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
                      _getController(
                          waypoint.getPrevControlLength().toStringAsFixed(2)),
                      'Previous Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          UndoRedo.addChange(_waypointChange(
                            wRef,
                            () => wRef.setPrevControlLength(value),
                            (oldVal) => wRef.setPrevControlLength(
                                oldVal.getPrevControlLength()),
                          ));
                        }
                      },
                    ),
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
                      _getController(
                          waypoint.getPrevControlLength().toStringAsFixed(2)),
                      'Previous Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          UndoRedo.addChange(_waypointChange(
                            wRef,
                            () => wRef.setPrevControlLength(value),
                            (oldVal) => wRef.setPrevControlLength(
                                oldVal.getPrevControlLength()),
                          ));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTextField(
                      _getController(
                          waypoint.getNextControlLength().toStringAsFixed(2)),
                      'Next Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          UndoRedo.addChange(_waypointChange(
                            wRef,
                            () => wRef.setNextControlLength(value),
                            (oldVal) => wRef.setNextControlLength(
                                oldVal.getNextControlLength()),
                          ));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add),
              label: const Text('Insert New Waypoint'),
            ),
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

  Change _waypointChange(
      Waypoint waypoint, VoidCallback execute, Function(Waypoint oldVal) undo) {
    return Change(
      waypoint.clone(),
      () {
        setState(() {
          execute.call();
          widget.onPathChanged?.call();
        });
      },
      (oldVal) {
        setState(() {
          undo.call(oldVal);
          widget.onPathChanged?.call();
        });
      },
    );
  }
}
