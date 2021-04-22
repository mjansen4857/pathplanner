import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path.dart';

// ignore: must_be_immutable
class WaypointCard extends StatelessWidget {
  final Waypoint waypoint;
  final String label;
  final bool holonomicEnabled;
  final bool deleteEnabled;
  final ValueChanged onXPosUpdate;
  final ValueChanged onYPosUpdate;
  final ValueChanged onHeadingUpdate;
  final ValueChanged onHolonomicUpdate;
  final ValueChanged onVelOverrideUpdate;
  final ValueChanged onReversalUpdate;
  final VoidCallback onDelete;

  TextEditingController xPosController;
  TextEditingController yPosController;
  TextEditingController headingController;
  TextEditingController holonomicController;
  TextEditingController velOverrideController;

  WaypointCard(this.waypoint,
      {this.label,
      this.holonomicEnabled,
      this.deleteEnabled,
      this.onXPosUpdate,
      this.onYPosUpdate,
      this.onHeadingUpdate,
      this.onHolonomicUpdate,
      this.onVelOverrideUpdate,
      this.onReversalUpdate,
      this.onDelete}) {
    if (waypoint != null) {
      xPosController =
          TextEditingController(text: waypoint.getXPos().toStringAsFixed(2));
      xPosController.selection = TextSelection.fromPosition(
          TextPosition(offset: xPosController.text.length));
      yPosController =
          TextEditingController(text: waypoint.getYPos().toStringAsFixed(2));
      yPosController.selection = TextSelection.fromPosition(
          TextPosition(offset: yPosController.text.length));
      headingController = TextEditingController(
          text: (waypoint.getHeadingRadians() * 180 / pi).toStringAsFixed(2));
      headingController.selection = TextSelection.fromPosition(
          TextPosition(offset: headingController.text.length));
      if (holonomicEnabled) {
        holonomicController = TextEditingController(
            text: waypoint.holonomicAngle.toStringAsFixed(2));
      } else {
        holonomicController = TextEditingController();
      }
      holonomicController.selection = TextSelection.fromPosition(
          TextPosition(offset: holonomicController.text.length));
      if (waypoint.velOverride != null && !waypoint.isReversal) {
        velOverrideController = TextEditingController(
            text: waypoint.velOverride.toStringAsFixed(2));
      } else {
        velOverrideController = TextEditingController();
      }
      velOverrideController.selection = TextSelection.fromPosition(
          TextPosition(offset: velOverrideController.text.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (waypoint == null) return Container();

    return Padding(
      padding: EdgeInsets.all(8),
      child: Container(
        width: 250,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 30,
                    ),
                    Text(label ?? 'Waypoint Label'),
                    SizedBox(
                      height: 30,
                      width: 30,
                      child: Visibility(
                        visible: deleteEnabled,
                        child: IconButton(
                          icon: Icon(
                            Icons.delete,
                          ),
                          onPressed: onDelete,
                          splashRadius: 20,
                          iconSize: 20,
                          padding: EdgeInsets.all(0),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                buildPositionRow(context),
                SizedBox(height: 12),
                buildAngleRow(context),
                Visibility(
                  child: SizedBox(height: 12),
                  visible: !waypoint.isStartPoint(),
                ),
                Visibility(
                  child: buildVelReversalRow(context),
                  visible: !waypoint.isStartPoint(),
                ),
                SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextFeild(BuildContext context, ValueChanged updateCallback,
      TextEditingController controller, String label,
      {bool enabled = true}) {
    return Container(
      width: 100,
      height: 35,
      child: TextField(
        onSubmitted: (val) {
          updateValue(updateCallback, val);
          unfocus(context);
        },
        enabled: enabled,
        controller: controller,
        cursorColor: Colors.white,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'(^(-?)\d*\.?\d*)')),
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

  Widget buildVelReversalRow(BuildContext context) {
    Widget reversal;
    if (!waypoint.isStartPoint() && !waypoint.isEndPoint()) {
      reversal = Row(
        children: [
          Checkbox(
            value: waypoint.isReversal,
            activeColor: Colors.indigo,
            onChanged: (val) {
              if (onReversalUpdate != null) {
                onReversalUpdate.call(val);
              }
            },
          ),
          Text('Reversal'),
        ],
      );
    } else {
      reversal = SizedBox(width: 90);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        buildTextFeild(
            context, onVelOverrideUpdate, velOverrideController, 'Vel Override',
            enabled: !waypoint.isReversal),
        SizedBox(width: 8),
        reversal,
        SizedBox(width: 14),
      ],
    );
  }

  Widget buildAngleRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        buildTextFeild(context, onHeadingUpdate, headingController, 'Heading'),
        SizedBox(
          width: 12,
        ),
        buildTextFeild(
            context, onHolonomicUpdate, holonomicController, 'Rotation',
            enabled: holonomicEnabled),
      ],
    );
  }

  Widget buildPositionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        buildTextFeild(context, onXPosUpdate, xPosController, 'X Position'),
        SizedBox(
          width: 12,
        ),
        buildTextFeild(context, onYPosUpdate, yPosController, 'Y Position'),
      ],
    );
  }

  void unfocus(BuildContext context) {
    FocusScopeNode currentScope = FocusScope.of(context);
    if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
      FocusManager.instance.primaryFocus.unfocus();
    }
  }

  void updateValue(ValueChanged callback, String val) {
    if (callback != null) {
      var parsed = double.tryParse(val);
      callback.call(parsed);
    }
  }
}
