import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';

class CommandCard extends StatefulWidget {
  final Command command;
  final ValueChanged<Command> onCommandChanged;

  const CommandCard({
    super.key,
    required this.command,
    required this.onCommandChanged,
  });

  @override
  State<CommandCard> createState() => _CommandCardState();
}

class _CommandCardState extends State<CommandCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                DropdownMenu<String>(
                  label: const Text('Command Type'),
                  dropdownMenuEntries: _getMenuEntries(),
                  initialSelection: widget.command.type,
                  onSelected: (value) {
                    if (value != null) {
                      Command cmd = widget.command.switchType(value);
                      widget.onCommandChanged.call(cmd);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuEntry<String>> _getMenuEntries() {
    return const [
      DropdownMenuEntry(
        value: 'named',
        label: 'Named Command',
      ),
      DropdownMenuEntry(
        value: 'wait',
        label: 'Wait Command',
      ),
      DropdownMenuEntry(
        value: 'sequential',
        label: 'Sequential Command Group',
      ),
      DropdownMenuEntry(
        value: 'parallel',
        label: 'Parallel Command Group',
      ),
      DropdownMenuEntry(
        value: 'race',
        label: 'Parallel Race Group',
      ),
    ];
  }
}
