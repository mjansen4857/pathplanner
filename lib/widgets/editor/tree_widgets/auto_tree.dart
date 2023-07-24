import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_auto.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';

class AutoTree extends StatefulWidget {
  final PathPlannerAuto auto;
  final List<String> allPathNames;
  final ValueChanged<String?>? onPathHovered;
  final VoidCallback? onSideSwapped;
  final VoidCallback? onAutoChanged;

  const AutoTree({
    super.key,
    required this.auto,
    required this.allPathNames,
    this.onPathHovered,
    this.onSideSwapped,
    this.onAutoChanged,
  });

  @override
  State<AutoTree> createState() => _AutoTreeState();
}

class _AutoTreeState extends State<AutoTree> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              const Text(
                'Simulated Driving Time: ~X.XXs',
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
                Card(
                  elevation: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CommandGroupWidget(
                      command: widget.auto.sequence,
                      allPathNames: widget.allPathNames,
                      removable: false,
                      onUpdated: () {
                        widget.onAutoChanged?.call();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
