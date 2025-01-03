import 'package:flutter/material.dart';
import 'package:pathplanner/commands/wait_until_command.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/named_conditional_widget.dart';
import 'package:undo/undo.dart';

class WaitUntilCommandWidget extends StatefulWidget {
  final WaitUntilCommand command;
  final VoidCallback? onUpdated;
  final VoidCallback? onRemoved;
  final ChangeStack undoStack;
  final VoidCallback? onDuplicateCommand;

  const WaitUntilCommandWidget({
    super.key,
    required this.command,
    this.onUpdated,
    this.onRemoved,
    required this.undoStack,
    this.onDuplicateCommand,
  });

  @override
  State<WaitUntilCommandWidget> createState() => _WaitUntilCommandWidgetState();
}

class _WaitUntilCommandWidgetState extends State<WaitUntilCommandWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: NamedConditionalWidget(
          conditional: widget.command.conditional,
          undoStack: widget.undoStack,
          onUpdated: widget.onUpdated,
          onRemoved: widget.onRemoved,
          onDuplicateCommand: widget.onDuplicateCommand,
          showDefaultValue: false,
        )),
      ],
    );
  }
}
