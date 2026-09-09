import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart'
    as legacy
    show
        DropdownButtonHideUnderline,
        InputDecoration,
        OutlineInputBorder,
        TextFormField;
import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/services/project_event_registry.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/duplicate_command_button.dart';
import 'package:pathplanner/widgets/legacy_material_bridge.dart';
import 'package:undo/undo.dart';

class NamedCommandWidget extends StatefulWidget {
  final NamedCommand command;
  final VoidCallback? onUpdated;
  final VoidCallback? onRemoved;
  final ChangeStack undoStack;
  final VoidCallback? onDuplicateCommand;

  const NamedCommandWidget({
    super.key,
    required this.command,
    this.onUpdated,
    this.onRemoved,
    required this.undoStack,
    this.onDuplicateCommand,
  });

  @override
  State<NamedCommandWidget> createState() => _NamedCommandWidgetState();
}

class _NamedCommandWidgetState extends State<NamedCommandWidget> {
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
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: LegacyMaterialBridge(
                child: legacy.DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    hint: const Text('Command Name'),
                    valueListenable: AlwaysStoppedAnimation(
                      widget.command.name,
                    ),
                    items: ProjectEventRegistry.events.isEmpty
                        ? [
                            // Workaround to prevent menu from disabling itself with empty items list
                            DropdownItem(
                              value: '',
                              enabled: false,
                              child: Text(
                                '',
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ]
                        : [
                            for (String event in ProjectEventRegistry.events)
                              if (event.isNotEmpty)
                                DropdownItem(
                                  value: event,
                                  child: Text(
                                    event,
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                          ],
                    buttonStyleData: ButtonStyleData(
                      padding: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.onSurface),
                      ),
                      height: 42,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 300,
                      isOverButton: true,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    menuItemStyleData: const MenuItemStyleData(),
                    dropdownSearchData: DropdownSearchData(
                      searchController: _controller,
                      searchBarWidgetHeight: 42,
                      searchBarWidget: Container(
                        height: 46,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                        child: legacy.TextFormField(
                          focusNode: _focusNode,
                          autofocus: true,
                          controller: _controller,
                          decoration: legacy.InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            hintText: 'Search or add new...',
                            hintStyle: const TextStyle(fontSize: 14),
                            border: legacy.OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onFieldSubmitted: (value) {
                            Navigator.of(context).pop();

                            if (value.isNotEmpty) {
                              widget.undoStack.add(
                                Change(
                                  widget.command.name,
                                  () {
                                    widget.command.name = value;
                                    ProjectEventRegistry.events.add(value);
                                    widget.onUpdated?.call();
                                  },
                                  (oldValue) {
                                    widget.command.name = oldValue;
                                    widget.onUpdated?.call();
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      searchMatchFn: (item, searchValue) {
                        return item.value.toString().toLowerCase().startsWith(
                          searchValue.toLowerCase(),
                        );
                      },
                    ),
                    onMenuStateChange: (isOpen) {
                      if (!isOpen) {
                        _controller.clear();
                      } else {
                        // Request focus after a delay to wait for the menu to open
                        Future.delayed(const Duration(milliseconds: 50))
                            .then((_) => _focusNode.requestFocus());
                      }
                    },
                    onChanged: (value) {
                      if (value != null && value.isNotEmpty) {
                        widget.undoStack.add(
                          Change(
                            widget.command.name,
                            () {
                              widget.command.name = value;
                              widget.onUpdated?.call();
                            },
                            (oldValue) {
                              widget.command.name = oldValue;
                              widget.onUpdated?.call();
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Visibility(
              visible: widget.command.name == null,
              child: Tooltip(
                message: 'Missing command name',
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[300]!,
                  size: 24,
                ),
              ),
            ),
            Visibility(
              visible: widget.onDuplicateCommand != null,
              child: DuplicateCommandButton(
                onPressed: widget.onDuplicateCommand,
              ),
            ),
            Tooltip(
              message: 'Remove Command',
              waitDuration: const Duration(milliseconds: 500),
              child: IconButton(
                onPressed: widget.onRemoved,
                visualDensity: const VisualDensity(
                  horizontal: VisualDensity.minimumDensity,
                  vertical: VisualDensity.minimumDensity,
                ),
                icon: Icon(Icons.delete, color: colorScheme.error),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
