import 'package:fitted_text_field_container/fitted_text_field_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pathplanner/robot_path.dart';

class PathTile extends StatefulWidget {
  final RobotPath path;
  final bool isSelected;
  final Key key;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  PathTile(this.path,
      {this.isSelected = false,
      this.onTap,
      this.key,
      this.onDuplicate,
      this.onDelete});

  @override
  _PathTileState createState() => _PathTileState();
}

class _PathTileState extends State<PathTile> {
  Widget buildTile() {
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
                    FocusScopeNode currentScope = FocusScope.of(context);
                    if (!currentScope.hasPrimaryFocus &&
                        currentScope.hasFocus) {
                      FocusManager.instance.primaryFocus.unfocus();
                    }
                    setState(() {
                      widget.path.name = text;
                    });
                  },
                  controller: TextEditingController(text: widget.path.name),
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

  @override
  Widget build(BuildContext context) {
    return buildTile();
  }
}
