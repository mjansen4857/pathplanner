import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pathplanner/robot_path/robot_path.dart';

typedef bool ValidRename(String name);

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
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _buildTile();
  }

  Widget _buildTile() {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Slidable(
        startActionPane: ActionPane(
          extentRatio: 0.4,
          motion: ScrollMotion(),
          children: [
            SlidableAction(
              backgroundColor: Colors.red,
              icon: Icons.delete,
              onPressed: (context) {
                widget.onDelete!();
              },
            ),
            SlidableAction(
              backgroundColor: Colors.blue,
              icon: Icons.content_copy,
              onPressed: (context) {
                widget.onDuplicate!();
              },
            ),
          ],
        ),
        child: Container(
          height: 50,
          width: 303,
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
                    padding: const EdgeInsets.only(top: 6, bottom: 7, left: 16),
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
      ),
    );
  }
}
