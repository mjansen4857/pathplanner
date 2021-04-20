import 'package:fitted_text_field_container/fitted_text_field_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path.dart';

class PathTile extends StatefulWidget {
  final RobotPath path;
  final bool isSelected;
  final Key key;
  final VoidCallback tapCallback;

  PathTile(this.path, this.key, {this.isSelected = false, this.tapCallback});

  @override
  _PathTileState createState() => _PathTileState();
}

class _PathTileState extends State<PathTile> {
  Widget buildTile() {
    return ListTile(
      key: widget.key,
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
    if (widget.isSelected) {
      return Column(
        children: [
          buildTile(),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(width: 25),
              Icon(Icons.subdirectory_arrow_right),
              SizedBox(width: 4),
              Container(
                width: 100,
                height: 30,
                child: TextField(
                  onSubmitted: (val) {
                    // updateValue(updateCallback, val);
                    // unfocus(context);
                  },
                  // controller: controller,
                  cursorColor: Colors.white,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)')),
                  ],
                  style: TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                    labelText: 'Max Vel',
                    filled: true,
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                width: 100,
                height: 30,
                child: TextField(
                  onSubmitted: (val) {
                    // updateValue(updateCallback, val);
                    // unfocus(context);
                  },
                  // controller: controller,
                  cursorColor: Colors.white,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)')),
                  ],
                  style: TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                    labelText: 'Max Accel',
                    filled: true,
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
        ],
      );
    } else {
      return buildTile();
    }
  }
}
