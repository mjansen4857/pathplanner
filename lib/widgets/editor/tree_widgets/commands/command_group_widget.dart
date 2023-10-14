import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/add_command_button.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/named_command_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/path_command_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/wait_command_widget.dart';
import 'package:undo/undo.dart';

class CommandGroupWidget extends StatelessWidget {
  final CommandGroup command;
  final VoidCallback? onUpdated;
  final VoidCallback? onRemoved;
  final ValueChanged<String>? onGroupTypeChanged;
  final double subCommandElevation;
  final bool removable;
  final List<String>? allPathNames;
  final ValueChanged<String?>? onPathCommandHovered;
  final ChangeStack undoStack;

  const CommandGroupWidget({
    super.key,
    required this.command,
    this.onUpdated,
    this.onGroupTypeChanged,
    this.onRemoved,
    this.subCommandElevation = 4.0,
    this.removable = true,
    this.allPathNames,
    this.onPathCommandHovered,
    required this.undoStack,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                child: ConditionalWidget(
                  condition: onGroupTypeChanged != null,
                  falseChild:
                      Text('$type Group', style: const TextStyle(fontSize: 16)),
                  trueChild: PopupMenuButton(
                    initialValue: command.type,
                    tooltip: '',
                    elevation: 12.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: onGroupTypeChanged,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'sequential',
                        child: Text('Sequential Group'),
                      ),
                      PopupMenuItem(
                        value: 'parallel',
                        child: Text('Parallel Group'),
                      ),
                      PopupMenuItem(
                        value: 'deadline',
                        child: Text('Deadline Group'),
                      ),
                      PopupMenuItem(
                        value: 'race',
                        child: Text('Race Group'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$type Group',
                              style: const TextStyle(fontSize: 16)),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: Container()),
            AddCommandButton(
              allowPathCommand: allPathNames != null,
              onTypeChosen: (value) {
                undoStack.add(Change(
                  CommandGroup.cloneCommandsList(command.commands),
                  () {
                    command.commands.add(Command.fromType(value));
                    onUpdated?.call();
                  },
                  (oldValue) {
                    command.commands = CommandGroup.cloneCommandsList(oldValue);
                    onUpdated?.call();
                  },
                ));
              },
            ),
            Visibility(
              visible: removable,
              child: Tooltip(
                message: 'Remove Command',
                waitDuration: const Duration(seconds: 1),
                child: IconButton(
                  onPressed: onRemoved,
                  visualDensity: const VisualDensity(
                      horizontal: VisualDensity.minimumDensity,
                      vertical: VisualDensity.minimumDensity),
                  icon: Icon(Icons.close, color: colorScheme.error),
                ),
              ),
            ),
          ],
        ),
        _buildReorderableList(context),
      ],
    );
  }

  Widget _buildReorderableList(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        if (command.commands[index] is PathCommand) {
          return MouseRegion(
            onEnter: (event) => onPathCommandHovered
                ?.call((command.commands[index] as PathCommand).pathName),
            onExit: (event) => onPathCommandHovered?.call(null),
            key: Key('$index'),
            child: Card(
              elevation: subCommandElevation,
              color: colorScheme.primaryContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PathCommandWidget(
                        command: command.commands[index] as PathCommand,
                        allPathNames: allPathNames ?? [],
                        onUpdated: onUpdated,
                        onRemoved: () => _removeCommand(index),
                        undoStack: undoStack,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return Card(
            elevation: subCommandElevation,
            key: Key('$index'),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
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
        }
      },
      itemCount: command.commands.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }

        undoStack.add(Change(
          CommandGroup.cloneCommandsList(command.commands),
          () {
            List<Command> cmds = List.of(command.commands);
            Command temp = cmds.removeAt(oldIndex);
            cmds.insert(newIndex, temp);
            command.commands = cmds;
            onUpdated?.call();
          },
          (oldValue) {
            command.commands = CommandGroup.cloneCommandsList(oldValue);
            onUpdated?.call();
          },
        ));
      },
    );
  }

  Widget _buildSubCommand(int cmdIndex) {
    if (command.commands[cmdIndex] is NamedCommand) {
      return NamedCommandWidget(
        command: command.commands[cmdIndex] as NamedCommand,
        onUpdated: onUpdated,
        onRemoved: () => _removeCommand(cmdIndex),
        undoStack: undoStack,
      );
    } else if (command.commands[cmdIndex] is WaitCommand) {
      return WaitCommandWidget(
        command: command.commands[cmdIndex] as WaitCommand,
        onUpdated: onUpdated,
        onRemoved: () => _removeCommand(cmdIndex),
        undoStack: undoStack,
      );
    } else if (command.commands[cmdIndex] is CommandGroup) {
      return CommandGroupWidget(
        command: command.commands[cmdIndex] as CommandGroup,
        undoStack: undoStack,
        subCommandElevation: (subCommandElevation == 1.0) ? 4.0 : 1.0,
        onUpdated: onUpdated,
        onRemoved: () => _removeCommand(cmdIndex),
        allPathNames: allPathNames,
        onPathCommandHovered: onPathCommandHovered,
        onGroupTypeChanged: (value) {
          undoStack.add(Change(
            command.commands[cmdIndex].type,
            () {
              List<Command> cmds =
                  (command.commands[cmdIndex] as CommandGroup).commands;
              command.commands[cmdIndex] =
                  Command.fromType(value, commands: cmds);
              onUpdated?.call();
            },
            (oldValue) {
              List<Command> cmds =
                  (command.commands[cmdIndex] as CommandGroup).commands;
              command.commands[cmdIndex] =
                  Command.fromType(oldValue, commands: cmds);
              onUpdated?.call();
            },
          ));
        },
      );
    }

    return Container();
  }

  void _removeCommand(int idx) {
    undoStack.add(Change(
      CommandGroup.cloneCommandsList(command.commands),
      () {
        command.commands.removeAt(idx);
        onUpdated?.call();
      },
      (oldValue) {
        command.commands = CommandGroup.cloneCommandsList(oldValue);
        onUpdated?.call();
      },
    ));
  }
}
