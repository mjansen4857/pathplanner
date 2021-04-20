import 'package:fitted_text_field_container/fitted_text_field_container.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path.dart';

class PathTile extends StatefulWidget {
  final RobotPath path;
  final bool isSelected;
  final Key key;
  final VoidCallback tapCallback;

  PathTile(this.path, {this.isSelected = false, this.tapCallback, this.key});

  @override
  _PathTileState createState() => _PathTileState();
}

class _PathTileState extends State<PathTile> {
  Widget buildTile() {
    return ListTile(
      selected: widget.isSelected,
      selectedTileColor: Colors.grey[800],
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: FittedTextFieldContainer(
          child: TextField(
            cursorColor: Colors.white,
            onSubmitted: (String text) {
              FocusScopeNode currentScope = FocusScope.of(context);
              if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
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
      onTap: widget.isSelected
          ? null
          : () {
              if (widget.tapCallback != null) {
                widget.tapCallback.call();
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildTile();
  }
}
