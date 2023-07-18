import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/named_command.dart';

class NamedCommandWidget extends StatefulWidget {
  final NamedCommand command;
  final VoidCallback onUpdated;
  final VoidCallback onRemoved;

  const NamedCommandWidget({
    super.key,
    required this.command,
    required this.onUpdated,
    required this.onRemoved,
  });

  @override
  State<NamedCommandWidget> createState() => _NamedCommandWidgetState();
}

class _NamedCommandWidgetState extends State<NamedCommandWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                child: DropdownMenu<String>(
                  label: const Text('Command Name'),
                  initialSelection: widget.command.name,
                  controller: _controller,
                  // TODO: flutter is busted (shocker) and hasn't released
                  // the fix for DropdownMenu width stuff yet even though it was
                  // merged 3 months ago :). Check back later
                  // width: Command.named.isEmpty ? 250 : null,
                  dropdownMenuEntries: List.generate(
                    Command.named.length,
                    (index) => DropdownMenuEntry(
                      value: Command.named.elementAt(index),
                      label: Command.named.elementAt(index),
                    ),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    isDense: true,
                    constraints: const BoxConstraints(
                      maxHeight: 42,
                    ),
                  ),
                  onSelected: (value) {
                    if (value != null) {
                      widget.command.name = value;
                    } else if (_controller.text.isNotEmpty) {
                      widget.command.name = _controller.text;
                    }
                    FocusScopeNode currentScope = FocusScope.of(context);
                    if (!currentScope.hasPrimaryFocus &&
                        currentScope.hasFocus) {
                      FocusManager.instance.primaryFocus!.unfocus();
                    }
                    widget.onUpdated.call();
                  },
                ),
              ),
            ),
            IconButton(
              onPressed: widget.onRemoved,
              visualDensity: const VisualDensity(
                  horizontal: VisualDensity.minimumDensity,
                  vertical: VisualDensity.minimumDensity),
              icon: Icon(Icons.close, color: colorScheme.error),
            ),
          ],
        )
      ],
    );
  }
}
