import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/add_command_button.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/named_command_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/wait_command_widget.dart';

class CommandGroupWidget extends StatelessWidget {
  final CommandGroup command;
  final VoidCallback onUpdated;
  final VoidCallback? onRemoved;
  final double subCommandElevation;
  final bool removable;

  const CommandGroupWidget({
    super.key,
    required this.command,
    required this.onUpdated,
    this.onRemoved,
    this.subCommandElevation = 4.0,
    this.removable = true,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    String type =
        '${command.type[0].toUpperCase()}${command.type.substring(1)}';

    return Column(
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text('$type Group', style: const TextStyle(fontSize: 16)),
            ),
            Expanded(child: Container()),
            AddCommandButton(
              onTypeChosen: (value) {
                command.commands.add(Command.defaultFromType(value));
                onUpdated.call();
              },
            ),
            Visibility(
              visible: removable,
              child: IconButton(
                onPressed: onRemoved,
                visualDensity: const VisualDensity(
                    horizontal: VisualDensity.minimumDensity,
                    vertical: VisualDensity.minimumDensity),
                icon: Icon(Icons.close, color: colorScheme.error),
              ),
            ),
          ],
        ),
        // if (command.commands.isNotEmpty) const Divider(),
        _buildReorderableList(),
      ],
    );
  }

  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        return Card(
          elevation: subCommandElevation,
          key: Key('$index'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildSubCommand(index)),
              ],
            ),
          ),
        );
      },
      itemCount: command.commands.length,
      onReorder: (oldIndex, newIndex) {
        // The fact that this needs to be here is so dumb
        if (newIndex >= command.commands.length) {
          newIndex = command.commands.length - 1;
        }

        List<Command> cmds = List.of(command.commands);
        Command temp = cmds.removeAt(oldIndex);
        cmds.insert(newIndex, temp);
        command.commands = cmds;
        onUpdated.call();
      },
    );
  }

  Widget _buildSubCommand(int cmdIndex) {
    if (command.commands[cmdIndex] is NamedCommand) {
      return NamedCommandWidget(
        command: command.commands[cmdIndex] as NamedCommand,
        onUpdated: onUpdated,
        onRemoved: () {
          command.commands.removeAt(cmdIndex);
          onUpdated.call();
        },
      );
    } else if (command.commands[cmdIndex] is WaitCommand) {
      return WaitCommandWidget(
        command: command.commands[cmdIndex] as WaitCommand,
        onUpdated: onUpdated,
        onRemoved: () {
          command.commands.removeAt(cmdIndex);
          onUpdated.call();
        },
      );
    } else if (command.commands[cmdIndex] is CommandGroup) {
      return CommandGroupWidget(
        command: command.commands[cmdIndex] as CommandGroup,
        subCommandElevation: (subCommandElevation == 1.0) ? 4.0 : 1.0,
        onUpdated: onUpdated,
        onRemoved: () {
          command.commands.removeAt(cmdIndex);
          onUpdated.call();
        },
      );
    }

    return Container();
  }
}
