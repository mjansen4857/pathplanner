import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/conditional_command_group.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/duplicate_command_button.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/named_conditional_widget.dart';
import 'package:undo/undo.dart';

class ConditionalCommandGroupWidget extends StatelessWidget {
  final ConditionalCommandGroup command;
  final VoidCallback? onUpdated;
  final VoidCallback? onRemoved;
  final double subCommandElevation;
  final List<String>? allPathNames;
  final ValueChanged<String?>? onPathCommandHovered;
  final ChangeStack undoStack;
  final VoidCallback? onDuplicateCommand;
  final bool showEditPathButton;
  final Function(String?)? onEditPathPressed;

  const ConditionalCommandGroupWidget({
    super.key,
    required this.command,
    this.onUpdated,
    this.onRemoved,
    this.subCommandElevation = 4.0,
    this.allPathNames,
    this.onPathCommandHovered,
    required this.undoStack,
    this.onDuplicateCommand,
    this.showEditPathButton = true,
    this.onEditPathPressed,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            const Text('Conditional Group', style: TextStyle(fontSize: 16)),
            Expanded(child: Container()),
            Visibility(
                visible: onDuplicateCommand != null,
                child: DuplicateCommandButton(
                  onPressed: onDuplicateCommand,
                )),
            Visibility(
              visible: onRemoved != null,
              child: Tooltip(
                message: 'Remove Command',
                waitDuration: const Duration(seconds: 1),
                child: IconButton(
                  onPressed: onRemoved,
                  visualDensity: const VisualDensity(
                      horizontal: VisualDensity.minimumDensity,
                      vertical: VisualDensity.minimumDensity),
                  icon: Icon(Icons.delete, color: colorScheme.error),
                ),
              ),
            ),
          ],
        ),
        Card(
          elevation: subCommandElevation,
          color: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(child: _buildSubCommand(0)),
              ],
            ),
          ),
        ),
        Card(
          elevation: subCommandElevation,
          color: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(child: _buildSubCommand(1)),
              ],
            ),
          ),
        ),
        Card(
          elevation: subCommandElevation,
          color: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                    child: NamedConditionalWidget(
                  undoStack: undoStack,
                  conditional: command.namedConditional,
                  onUpdated: onUpdated,
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubCommand(int cmdIndex) {
    var cmd = cmdIndex == 0 ? command.onTrue : command.onFalse;
    if (cmd is CommandGroup) {
      return CommandGroupWidget(
        command: cmd,
        undoStack: undoStack,
        subCommandElevation: (subCommandElevation == 1.0) ? 4.0 : 1.0,
        onUpdated: onUpdated,
        allPathNames: allPathNames,
        onPathCommandHovered: onPathCommandHovered,
        showEditPathButton: showEditPathButton,
        onEditPathPressed: onEditPathPressed,
        onGroupTypeChanged: (value) {
          undoStack.add(Change(
            cmd.type,
            () {
              var cmd = cmdIndex == 0 ? command.onTrue : command.onFalse;
              List<Command> cmds = (cmd as CommandGroup).commands;
              final newCmd = Command.fromType(value, commands: cmds);
              if (newCmd != null) {
                if (cmdIndex == 0) {
                  command.onTrue = newCmd;
                } else {
                  command.onFalse = newCmd;
                }
                onUpdated?.call();
              }
            },
            (oldValue) {
              var cmd = cmdIndex == 0 ? command.onTrue : command.onFalse;
              List<Command> cmds = (cmd as CommandGroup).commands;
              final oldCmd = Command.fromType(oldValue, commands: cmds);
              if (oldCmd != null) {
                if (cmdIndex == 0) {
                  command.onTrue = oldCmd;
                } else {
                  command.onFalse = oldCmd;
                }
                onUpdated?.call();
              }
            },
          ));
        },
      );
    }

    return Container();
  }
}
