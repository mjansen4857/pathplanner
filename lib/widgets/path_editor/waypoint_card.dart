import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:undo/undo.dart';
import 'package:function_tree/function_tree.dart';

class WaypointCard extends StatefulWidget {
  final Waypoint? waypoint;
  final String? label;
  final bool holonomicEnabled;
  final bool deleteEnabled;
  final VoidCallback? onDelete;
  final VoidCallback? onShouldSave;
  final void Function(Offset, Size)? onDragged;
  final VoidCallback? onDragFinished;

  WaypointCard(this.waypoint,
      {this.label,
      this.holonomicEnabled = false,
      this.deleteEnabled = false,
      this.onDelete,
      this.onShouldSave,
      this.onDragged,
      this.onDragFinished});

  @override
  _WaypointCardState createState() => _WaypointCardState();
}

class _WaypointCardState extends State<WaypointCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.waypoint == null) return Container();

    return DraggableCard(
      onDragged: widget.onDragged,
      onDragFinished: widget.onDragFinished,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          SizedBox(height: 12),
          // Override gesture detector on UI elements so they wont cause the card to move
          GestureDetector(
            onPanStart: (details) {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPositionRow(context),
                SizedBox(height: 12),
                _buildAngleRow(context),
                SizedBox(height: 12),
                _buildVelReversalRow(context),
                SizedBox(height: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          height: 30,
          width: 30,
          // Override gesture detector on UI elements so they wont cause the card to move
          child: GestureDetector(
            onPanStart: (details) {},
            child: IconButton(
              tooltip: widget.waypoint!.isLocked
                  ? 'Unlock Waypoint'
                  : 'Lock Waypoint',
              icon: Icon(
                widget.waypoint!.isLocked ? Icons.lock : Icons.lock_open,
              ),
              onPressed: () {
                setState(() {
                  widget.waypoint!.isLocked = !widget.waypoint!.isLocked;
                  if (widget.onShouldSave != null) {
                    widget.onShouldSave!.call();
                  }
                });
              },
              splashRadius: 20,
              iconSize: 20,
              padding: EdgeInsets.all(0),
            ),
          ),
        ),
        Text(widget.label ?? 'Waypoint Label'),
        SizedBox(
          height: 30,
          width: 30,
          child: Visibility(
            visible: widget.deleteEnabled,
            // Override gesture detector on UI elements so they wont cause the card to move
            child: GestureDetector(
              onPanStart: (details) {},
              child: IconButton(
                tooltip: 'Delete Waypoint',
                icon: Icon(
                  Icons.delete,
                ),
                onPressed: widget.onDelete,
                splashRadius: 20,
                iconSize: 20,
                padding: EdgeInsets.all(0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildTextField(
          context,
          _getController(widget.waypoint!.getXPos().toStringAsFixed(2)),
          'X Position',
          onSubmitted: (val) {
            Waypoint wRef = widget.waypoint!;
            UndoRedo.addChange(_cardChange(
              () => wRef.move(val, wRef.anchorPoint.y),
              (oldVal) => wRef.move(oldVal.anchorPoint.x, oldVal.anchorPoint.y),
            ));
          },
        ),
        SizedBox(width: 12),
        _buildTextField(
          context,
          _getController(widget.waypoint!.getYPos().toStringAsFixed(2)),
          'Y Position',
          onSubmitted: (val) {
            Waypoint? wRef = widget.waypoint;
            UndoRedo.addChange(_cardChange(
              () => wRef!.move(wRef.anchorPoint.x, val),
              (oldVal) =>
                  wRef!.move(oldVal.anchorPoint.x, oldVal.anchorPoint.y),
            ));
          },
        ),
      ],
    );
  }

  Widget _buildAngleRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildTextField(
          context,
          _getController(
              widget.waypoint!.getHeadingDegrees().toStringAsFixed(2)),
          'Heading',
          onSubmitted: (val) {
            Waypoint? wRef = widget.waypoint;
            UndoRedo.addChange(_cardChange(
              () => wRef!.setHeading(val),
              (oldVal) => wRef!.setHeading(oldVal.getHeadingDegrees()),
            ));
          },
        ),
        SizedBox(width: 12),
        _buildTextField(
          context,
          !widget.holonomicEnabled
              ? _getController("")
              : _getController(
                  widget.waypoint!.holonomicAngle.toStringAsFixed(2)),
          'Rotation',
          enabled: widget.holonomicEnabled,
          onSubmitted: (val) {
            Waypoint? wRef = widget.waypoint;
            UndoRedo.addChange(_cardChange(
              () => wRef!.holonomicAngle = val,
              (oldVal) => wRef!.holonomicAngle = oldVal.holonomicAngle,
            ));
          },
        ),
      ],
    );
  }

  Widget _buildVelReversalRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildTextField(
          context,
          widget.waypoint!.isReversal || widget.waypoint!.velOverride == null
              ? _getController("")
              : _getController(
                  widget.waypoint!.velOverride!.toStringAsFixed(2)),
          'Vel Override',
          enabled: !widget.waypoint!.isReversal,
          onSubmitted: (val) {
            if (val == 0.0) val = null;
            Waypoint? wRef = widget.waypoint;
            UndoRedo.addChange(_cardChange(
              () => wRef!.velOverride = val,
              (oldVal) => wRef!.velOverride = oldVal.velOverride,
            ));
          },
        ),
        SizedBox(width: 8),
        _buildReversalWidget(),
        SizedBox(width: 14),
      ],
    );
  }

  Widget _buildReversalWidget() {
    if (widget.waypoint!.isStartPoint() || widget.waypoint!.isEndPoint()) {
      return SizedBox(width: 90);
    } else {
      return Row(
        children: [
          Checkbox(
            value: widget.waypoint!.isReversal,
            activeColor: Colors.indigo,
            onChanged: (val) {
              Waypoint? wRef = widget.waypoint;
              UndoRedo.addChange(_cardChange(
                () => wRef!.setReversal(val!),
                (oldVal) => wRef!.setReversal(oldVal.isReversal),
              ));
            },
          ),
          Text('Reversal'),
        ],
      );
    }
  }

  Widget _buildTextField(
      BuildContext context, TextEditingController? controller, String label,
      {bool? enabled = true, ValueChanged? onSubmitted}) {
    return Container(
      width: 100,
      height: 35,
      child: TextField(
        onSubmitted: (val) {
          if (onSubmitted != null) {
            num parsed = val.interpret();
            onSubmitted.call(parsed);
          }
          FocusScopeNode currentScope = FocusScope.of(context);
          if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
            FocusManager.instance.primaryFocus!.unfocus();
          }
        },
        enabled: enabled,
        controller: controller,
        cursorColor: Colors.white,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(r'(^(-?)\d*\.?\d*)([+/\*\-](-?)\d*\.?\d*)*')),
        ],
        style: TextStyle(fontSize: 14),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
          labelText: label,
          filled: true,
          border:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          focusedBorder:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          labelStyle: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Change _cardChange(VoidCallback execute, Function(Waypoint oldVal) undo) {
    return Change(
      widget.waypoint!.clone(),
      () {
        setState(() {
          execute.call();
          if (widget.onShouldSave != null) {
            widget.onShouldSave!.call();
          }
        });
      },
      (oldVal) {
        setState(() {
          undo.call(oldVal);
          if (widget.onShouldSave != null) {
            widget.onShouldSave!.call();
          }
        });
      },
    );
  }

  TextEditingController _getController(String text) {
    return TextEditingController(text: text)
      ..selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
  }
}
