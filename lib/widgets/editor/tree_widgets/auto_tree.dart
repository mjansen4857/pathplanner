import 'package:flutter/material.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/editor_settings_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/reset_odom_tree.dart';
import 'package:undo/undo.dart';

class AutoTree extends StatefulWidget {
  final PathPlannerAuto auto;
  final List<String> allPathNames;
  final ValueChanged<String?>? onPathHovered;
  final VoidCallback? onSideSwapped;
  final VoidCallback? onAutoChanged;
  final ChangeStack undoStack;
  final num? autoRuntime;
  final Function(String?)? onEditPathPressed;

  const AutoTree({
    super.key,
    required this.auto,
    required this.allPathNames,
    this.onPathHovered,
    this.onSideSwapped,
    this.onAutoChanged,
    required this.undoStack,
    this.autoRuntime,
    this.onEditPathPressed,
  });

  @override
  State<AutoTree> createState() => _AutoTreeState();
}

class _AutoTreeState extends State<AutoTree> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Text(
                'Simulated Driving Time: ~${(widget.autoRuntime ?? 0).toStringAsFixed(2)}s',
                style: const TextStyle(fontSize: 18),
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
                  color: colorScheme.surface,
                  surfaceTintColor: colorScheme.surfaceTint,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CommandGroupWidget(
                      command: widget.auto.sequence,
                      allPathNames: widget.allPathNames,
                      onPathCommandHovered: widget.onPathHovered,
                      onUpdated: widget.onAutoChanged,
                      undoStack: widget.undoStack,
                      showEditPathButton: !widget.auto.choreoAuto,
                      onEditPathPressed: widget.onEditPathPressed,
                    ),
                  ),
                ),
                ResetOdomTree(
                  auto: widget.auto,
                  onAutoChanged: widget.onAutoChanged,
                  undoStack: widget.undoStack,
                ),
                const Divider(),
                const EditorSettingsTree(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
