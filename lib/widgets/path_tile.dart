import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/widgets/custom_popup_menu.dart' as custom;

enum MenuOptions {
  delete,
  duplicate,
}

class PathTile extends StatefulWidget {
  final RobotPath path;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final bool Function(String name) onRename;

  const PathTile(
      {required this.path,
      this.isSelected = false,
      required this.onTap,
      required this.onDuplicate,
      required this.onDelete,
      required this.onRename,
      super.key});

  @override
  State<PathTile> createState() => _PathTileState();
}

class _PathTileState extends State<PathTile> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 56,
          width: 303,
          color: widget.isSelected
              ? colorScheme.surfaceVariant
              : Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: widget.isSelected
                      ? MouseCursor.defer
                      : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.isSelected ? null : widget.onTap,
                    child: Container(
                      color: widget.isSelected
                          ? colorScheme.surfaceVariant
                          : Colors.transparent,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 8, bottom: 8, left: 16),
                          child: _buildTextField(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildPopupMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return IntrinsicWidth(
      child: TextField(
        onSubmitted: (String text) {
          if (text != '') {
            FocusScopeNode currentScope = FocusScope.of(context);
            if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
              FocusManager.instance.primaryFocus!.unfocus();
            }
            if (widget.onRename(text)) {
              setState(() {
                widget.path.name = text;
              });
            }
          } else {
            setState(() {
              // flutter be weird sometimes
              widget.path.name = widget.path.name;
            });
          }
        },
        style: TextStyle(
            color: widget.isSelected
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurface),
        controller: TextEditingController(text: widget.path.name)
          ..selection = TextSelection.fromPosition(
              TextPosition(offset: widget.path.name.length)),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: colorScheme.outline,
            ),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.transparent,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp('["*<>?|/:\\\\]')),
        ],
      ),
    );
  }

  Widget _buildPopupMenu() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Visibility(
      visible: widget.isSelected,
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: SizedBox(
          width: 48,
          child: custom.PopupMenuButton<MenuOptions>(
            color: colorScheme.surfaceVariant,
            icon: Icon(
              Icons.adaptive.more,
              color: widget.isSelected
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ),
            splashRadius: 18,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tooltip: '',
            onSelected: (MenuOptions value) {
              switch (value) {
                case MenuOptions.delete:
                  widget.onDelete();
                  break;
                case MenuOptions.duplicate:
                  widget.onDuplicate();
              }
            },
            itemBuilder: (BuildContext context) =>
                <custom.PopupMenuEntry<MenuOptions>>[
              custom.PopupMenuItem<MenuOptions>(
                value: MenuOptions.delete,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              custom.PopupMenuItem<MenuOptions>(
                value: MenuOptions.duplicate,
                child: Row(
                  children: [
                    Icon(
                      Icons.copy,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Duplicate',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
