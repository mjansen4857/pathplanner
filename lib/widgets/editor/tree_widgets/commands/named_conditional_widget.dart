import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/commands/conditional_command_group.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/duplicate_command_button.dart';
import 'package:undo/undo.dart';

class NamedConditionalWidget extends StatefulWidget {
  final NamedConditional conditional;
  final VoidCallback? onUpdated;
  final ChangeStack undoStack;
  final bool showDefaultValue;
  final VoidCallback? onDuplicateCommand;
  final VoidCallback? onRemoved;

  const NamedConditionalWidget({
    super.key,
    required this.conditional,
    this.onUpdated,
    required this.undoStack,
    this.onDuplicateCommand,
    this.onRemoved,
    this.showDefaultValue = true,
  });

  @override
  State<NamedConditionalWidget> createState() => _NamedConditionalWidgetState();
}

class _NamedConditionalWidgetState extends State<NamedConditionalWidget> {
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
              child: DropdownButtonFormField2<String>(
                hint: const Text('Conditional Name'),
                value: widget.conditional.name,
                barrierLabel: 'Conditional Name',
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  labelText: 'Conditional Name',
                  border: InputBorder.none,
                ),
                items: ProjectPage.conditions.isEmpty
                    ? [
                        // Workaround to prevent menu from disabling itself with empty items list
                        DropdownMenuItem(
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
                        for (String event in ProjectPage.conditions)
                          if (event.isNotEmpty)
                            DropdownMenuItem(
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
                    border: Border.all(
                      color: colorScheme.onSurface,
                    ),
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
                  searchInnerWidgetHeight: 42,
                  searchInnerWidget: Container(
                    height: 46,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: TextFormField(
                      focusNode: _focusNode,
                      autofocus: true,
                      controller: _controller,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        hintText: 'Search or add new...',
                        hintStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onFieldSubmitted: (value) {
                        Navigator.of(context).pop();

                        if (value.isNotEmpty) {
                          widget.undoStack.add(Change(
                            widget.conditional.name,
                            () {
                              widget.conditional.name = value;
                              ProjectPage.conditions.add(value);
                              widget.onUpdated?.call();
                            },
                            (oldValue) {
                              widget.conditional.name = oldValue;
                              widget.onUpdated?.call();
                            },
                          ));
                        }
                      },
                    ),
                  ),
                  searchMatchFn: (item, searchValue) {
                    return item.value
                        .toString()
                        .toLowerCase()
                        .startsWith(searchValue.toLowerCase());
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
                    widget.undoStack.add(Change(
                      widget.conditional.name,
                      () {
                        widget.conditional.name = value;
                        widget.onUpdated?.call();
                      },
                      (oldValue) {
                        widget.conditional.name = oldValue;
                        widget.onUpdated?.call();
                      },
                    ));
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Visibility(
              visible: widget.conditional.name == null,
              child: Tooltip(
                message: 'Missing conditional name',
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[300]!,
                  size: 24,
                ),
              ),
            ),
            if (widget.showDefaultValue)
              Tooltip(
                  message: 'Default Value in Simulation for this Conditional',
                  waitDuration: const Duration(seconds: 1),
                  child: Checkbox(
                      value: widget.conditional.defaultValue,
                      onChanged: (value) {
                        if (value != null) {
                          widget.undoStack
                              .add(Change(widget.conditional.defaultValue, () {
                            widget.conditional.defaultValue = value;
                            widget.onUpdated?.call();
                          }, (oldValue) {
                            widget.conditional.defaultValue = oldValue;
                            widget.onUpdated?.call();
                          }));
                        }
                      })),
            Visibility(
              visible: widget.onDuplicateCommand != null,
              child: DuplicateCommandButton(
                onPressed: widget.onDuplicateCommand,
              ),
            ),
            Visibility(
                visible: widget.onRemoved != null,
                child: Tooltip(
                  message: 'Remove Command',
                  waitDuration: const Duration(milliseconds: 500),
                  child: IconButton(
                    onPressed: widget.onRemoved,
                    visualDensity: const VisualDensity(
                        horizontal: VisualDensity.minimumDensity,
                        vertical: VisualDensity.minimumDensity),
                    icon: Icon(Icons.delete, color: colorScheme.error),
                  ),
                )),
          ],
        )
      ],
    );
  }
}
