import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/widgets/custom_popup_menu.dart' as custom;

enum MenuOptions {
  Delete,
  Duplicate,
}

class PathTile extends StatefulWidget {
  final RobotPath path;
  final bool isSelected;
  final Key? key;
  final VoidCallback? onTap;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final bool Function(String name)? onRename;

  PathTile(this.path,
      {this.isSelected = false,
      this.onTap,
      this.key,
      this.onDuplicate,
      this.onDelete,
      this.onRename});

  @override
  _PathTileState createState() => _PathTileState();
}

class _PathTileState extends State<PathTile> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 303,
      color: widget.isSelected
          ? Theme.of(context).colorScheme.surfaceVariant
          : Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildPopupMenu(context),
          Expanded(
            child: MouseRegion(
              cursor: widget.isSelected
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.isSelected ? null : widget.onTap,
                child: Container(
                  color: widget.isSelected
                      ? Theme.of(context).colorScheme.surfaceVariant
                      : Colors.transparent,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: 6, bottom: 7, left: 2),
                      child: _buildTextField(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return IntrinsicWidth(
      child: TextField(
        onSubmitted: (String text) {
          if (text != '') {
            FocusScopeNode currentScope = FocusScope.of(context);
            if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
              FocusManager.instance.primaryFocus!.unfocus();
            }
            if (widget.onRename != null) {
              if (widget.onRename!.call(text)) {
                setState(() {
                  widget.path.name = text;
                });
              }
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
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface),
        controller: TextEditingController(text: widget.path.name)
          ..selection = TextSelection.fromPosition(
              TextPosition(offset: widget.path.name.length)),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.transparent,
            ),
          ),
          contentPadding: EdgeInsets.all(8),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp("[\"*<>?\|/:\\\\]")),
        ],
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return custom.PopupMenuButton<MenuOptions>(
      color: Theme.of(context).colorScheme.surfaceVariant,
      icon: Icon(
        Icons.adaptive.more,
        color: widget.isSelected
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.onSurface,
      ),
      splashRadius: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tooltip: '',
      onSelected: (MenuOptions value) {
        switch (value) {
          case MenuOptions.Delete:
            if (widget.onDelete != null) {
              widget.onDelete!.call();
            }
            break;
          case MenuOptions.Duplicate:
            if (widget.onDuplicate != null) {
              widget.onDuplicate!.call();
            }
        }
      },
      itemBuilder: (BuildContext context) =>
          <custom.PopupMenuEntry<MenuOptions>>[
        custom.PopupMenuItem<MenuOptions>(
          value: MenuOptions.Delete,
          child: Row(
            children: [
              Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: 12),
              Text(
                'Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        custom.PopupMenuItem<MenuOptions>(
          value: MenuOptions.Duplicate,
          child: Row(
            children: [
              Icon(
                Icons.copy,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: 12),
              Text(
                'Duplicate',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
