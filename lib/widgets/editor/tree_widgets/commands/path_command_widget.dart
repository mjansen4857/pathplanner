import 'package:flutter/material.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:undo/undo.dart';

class PathCommandWidget extends StatefulWidget {
  final PathCommand command;
  final List<String> allPathNames;
  final VoidCallback onUpdated;
  final VoidCallback onRemoved;

  const PathCommandWidget({
    super.key,
    required this.command,
    required this.allPathNames,
    required this.onUpdated,
    required this.onRemoved,
  });

  @override
  State<PathCommandWidget> createState() => _PathCommandWidgetState();
}

class _PathCommandWidgetState extends State<PathCommandWidget> {
  TextEditingController _controller = TextEditingController();

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
                  label: const Text('Path Name'),
                  controller: _controller,
                  initialSelection: widget.command.pathName,
                  // TODO: flutter is busted (shocker) and hasn't released
                  // the fix for DropdownMenu width stuff yet even though it was
                  // merged 3 months ago :). Check back later
                  // width: Command.named.isEmpty ? 250 : null,
                  dropdownMenuEntries: List.generate(
                    widget.allPathNames.length,
                    (index) => DropdownMenuEntry(
                      value: widget.allPathNames[index],
                      label: widget.allPathNames[index],
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

                    if (value != null) {
                      UndoRedo.addChange(Change(
                        widget.command.pathName,
                        () {
                          widget.command.pathName = value;
                          widget.onUpdated.call();
                        },
                        (oldValue) {
                          widget.command.pathName = oldValue;
                          widget.onUpdated.call();
                        },
                      ));
                    } else if (widget.command.pathName != null) {
                      _controller.text = widget.command.pathName!;
                    }
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
