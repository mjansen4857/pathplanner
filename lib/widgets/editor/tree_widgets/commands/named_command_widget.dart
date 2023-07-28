import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:undo/undo.dart';

class NamedCommandWidget extends StatefulWidget {
  final NamedCommand command;
  final VoidCallback onUpdated;
  final VoidCallback onRemoved;
  final ChangeStack undoStack;

  const NamedCommandWidget({
    super.key,
    required this.command,
    required this.onUpdated,
    required this.onRemoved,
    required this.undoStack,
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
                    FocusScopeNode currentScope = FocusScope.of(context);
                    if (!currentScope.hasPrimaryFocus &&
                        currentScope.hasFocus) {
                      FocusManager.instance.primaryFocus!.unfocus();
                    }

                    String text = _controller.text;
                    widget.undoStack.add(Change(
                      widget.command.name,
                      () {
                        if (value != null) {
                          widget.command.name = value;
                        } else if (text.isNotEmpty) {
                          widget.command.name = text;
                        }
                        _controller.text = text;
                        widget.onUpdated.call();
                      },
                      (oldValue) {
                        widget.command.name = oldValue;
                        _controller.text = oldValue ?? '';
                        widget.onUpdated.call();
                      },
                    ));
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
