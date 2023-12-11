import 'package:flutter/material.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/editor_settings_tree.dart';
import 'package:undo/undo.dart';

class ChoreoPathTree extends StatefulWidget {
  final ChoreoPath path;
  final VoidCallback? onSideSwapped;
  final ChangeStack undoStack;
  final num? pathRuntime;

  const ChoreoPathTree({
    super.key,
    required this.path,
    this.onSideSwapped,
    required this.undoStack,
    this.pathRuntime,
  });

  @override
  State<ChoreoPathTree> createState() => _ChoreoPathTreeState();
}

class _ChoreoPathTreeState extends State<ChoreoPathTree> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Text(
                'Simulated Driving Time: ~${(widget.pathRuntime ?? 0).toStringAsFixed(2)}s',
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
        const Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Divider(),
                EditorSettingsTree(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
