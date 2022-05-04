import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/widgets/custom_popup_menu.dart' as custom;

typedef bool ValidRename(String name);

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
  final ValidRename? onRename;

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
      color: widget.isSelected ? Colors.grey[800] : Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          custom.PopupMenuButton<MenuOptions>(
            splashRadius: 18,
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
                    Icon(Icons.delete),
                    SizedBox(width: 12),
                    Text('Delete'),
                  ],
                ),
              ),
              custom.PopupMenuItem<MenuOptions>(
                value: MenuOptions.Duplicate,
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 12),
                    Text('Duplicate'),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: MouseRegion(
              cursor: widget.isSelected
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.isSelected ? null : widget.onTap,
                child: Container(
                  color:
                      widget.isSelected ? Colors.grey[800] : Colors.transparent,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: 6, bottom: 7, left: 2),
                      child: IntrinsicWidth(
                        child: TextField(
                          cursorColor: Colors.white,
                          onSubmitted: (String text) {
                            if (text != '') {
                              FocusScopeNode currentScope =
                                  FocusScope.of(context);
                              if (!currentScope.hasPrimaryFocus &&
                                  currentScope.hasFocus) {
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
                          controller: TextEditingController(
                              text: widget.path.name)
                            ..selection = TextSelection.fromPosition(
                                TextPosition(offset: widget.path.name.length)),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey,
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
                            FilteringTextInputFormatter.deny(
                                RegExp("[\"*<>?\|/:\\\\]")),
                          ],
                        ),
                      ),
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
}
