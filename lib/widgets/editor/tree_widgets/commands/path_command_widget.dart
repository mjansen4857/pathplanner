import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/duplicate_command_button.dart';
import 'package:undo/undo.dart';

class PathCommandWidget extends StatefulWidget {
  final PathCommand command;
  final List<String> allPathNames;
  final VoidCallback? onUpdated;
  final VoidCallback? onRemoved;
  final ChangeStack undoStack;
  final VoidCallback? onDuplicateCommand;
  final Function(String?)? onEditPathPressed;
  final bool showEditButton;

  const PathCommandWidget({
    super.key,
    required this.command,
    required this.allPathNames,
    this.onUpdated,
    this.onRemoved,
    required this.undoStack,
    this.onDuplicateCommand,
    this.onEditPathPressed,
    this.showEditButton = true,
  });

  @override
  State<PathCommandWidget> createState() => _PathCommandWidgetState();
}

class _PathCommandWidgetState extends State<PathCommandWidget> {
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

    return Row(
      children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isExpanded: true,
              hint: const Text('Path Name'),
              value: widget.command.pathName,
              items: List.generate(
                widget.allPathNames.length,
                (index) => DropdownMenuItem(
                  value: widget.allPathNames[index],
                  child: Tooltip(
                    message: widget.allPathNames[index],
                    child: Text(
                      widget.allPathNames[index],
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              buttonStyleData: ButtonStyleData(
                padding: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.onPrimaryContainer,
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
                      hintText: 'Search...',
                      hintStyle: const TextStyle(fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
                FocusScopeNode currentScope = FocusScope.of(context);
                if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
                  FocusManager.instance.primaryFocus!.unfocus();
                }

                if (value != null) {
                  widget.undoStack.add(Change(
                    widget.command.pathName,
                    () {
                      widget.command.pathName = value;
                      widget.onUpdated?.call();
                    },
                    (oldValue) {
                      widget.command.pathName = oldValue;
                      widget.onUpdated?.call();
                    },
                  ));
                } else if (widget.command.pathName != null) {
                  _controller.text = widget.command.pathName!;
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        ConditionalWidget(
          condition: widget.command.pathName == null,
          trueChild: Tooltip(
            message: 'Missing path name',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[300]!,
                size: 32,
              ),
            ),
          ),
          falseChild: Visibility(
            visible: widget.showEditButton,
            child: Tooltip(
              message: 'Edit Path',
              child: IconButton(
                onPressed: () =>
                    widget.onEditPathPressed?.call(widget.command.pathName),
                icon: const Icon(Icons.edit),
              ),
            ),
          ),
        ),
        DuplicateCommandButton(
          onPressed: widget.onDuplicateCommand,
        ),
        Tooltip(
          message: 'Remove Command',
          waitDuration: const Duration(milliseconds: 500),
          child: IconButton(
            onPressed: widget.onRemoved,
            visualDensity: const VisualDensity(
                horizontal: VisualDensity.minimumDensity,
                vertical: VisualDensity.minimumDensity),
            icon: Icon(Icons.delete, color: colorScheme.error),
          ),
        ),
      ],
    );
  }
}
