import 'dart:io';

import 'package:fitted_text_field_container/fitted_text_field_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pathplanner/robot_path/robot_path.dart';

typedef bool ValidRename(String name);

class PathTile extends StatefulWidget {
  final RobotPath path;
  final bool isSelected;
  final Key key;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValidRename onRename;

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
  String _name;

  @override
  void initState() {
    super.initState();
    _name = widget.path.name;
  }

  @override
  Widget build(BuildContext context) {
    return _buildTile();
  }

  Widget _buildTile() {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Slidable(
        actionPane: SlidableScrollActionPane(),
        actionExtentRatio: 0.25,
        actions: [
          IconSlideAction(
            caption: 'Delete',
            color: Colors.red,
            icon: Icons.delete,
            onTap: widget.onDelete,
          ),
          IconSlideAction(
            caption: 'Duplicate',
            color: Colors.indigo,
            icon: Icons.copy,
            onTap: widget.onDuplicate,
          ),
        ],
        child: ListTile(
            selected: widget.isSelected,
            selectedTileColor: Colors.grey[800],
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: FittedTextFieldContainer(
                child: TextField(
                  cursorColor: Colors.white,
                  onSubmitted: (String text) {
                    if (text != null && text != '') {
                      FocusScopeNode currentScope = FocusScope.of(context);
                      if (!currentScope.hasPrimaryFocus &&
                          currentScope.hasFocus) {
                        FocusManager.instance.primaryFocus.unfocus();
                      }
                      if (widget.onRename != null) {
                        if (widget.onRename.call(text)) {
                          setState(() {
                            _name = text;
                            widget.path.name = text;
                          });
                        }
                      }
                    } else {
                      setState(() {
                        _name = widget.path.name;
                      });
                    }
                  },
                  controller: TextEditingController(text: _name)
                    ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _name.length)),
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
                    // errorBorder: InputBorder.none,
                    // disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.all(8),
                  ),
                ),
              ),
            ),
            onTap: widget.isSelected ? null : widget.onTap),
      ),
    );
  }
}
