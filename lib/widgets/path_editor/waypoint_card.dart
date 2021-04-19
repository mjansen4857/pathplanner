import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path.dart';

typedef void ValueUpdateCallback(double val);

// ignore: must_be_immutable
class WaypointCard extends StatelessWidget {
  final Waypoint waypoint;
  final String label;
  final ValueUpdateCallback onXPosUpdate;
  final ValueUpdateCallback onYPosUpdate;

  TextEditingController xPosController;
  TextEditingController yPosController;

  WaypointCard(this.waypoint,
      {this.label, this.onXPosUpdate, this.onYPosUpdate}) {
    if (waypoint != null) {
      xPosController =
          TextEditingController(text: waypoint.getXPos().toStringAsFixed(2));
      xPosController.selection = TextSelection.fromPosition(
          TextPosition(offset: xPosController.text.length));
      yPosController =
          TextEditingController(text: waypoint.getYPos().toStringAsFixed(2));
      yPosController.selection = TextSelection.fromPosition(
          TextPosition(offset: yPosController.text.length));
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
                Text(label ?? 'Waypoint Label'),
                SizedBox(
                  height: 12,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: 100,
                      height: 35,
                      child: TextField(
                        onSubmitted: (val) {
                          if (onXPosUpdate != null)
                            onXPosUpdate.call(double.parse(val));
                          FocusScopeNode currentScope = FocusScope.of(context);
                          if (!currentScope.hasPrimaryFocus &&
                              currentScope.hasFocus) {
                            FocusManager.instance.primaryFocus.unfocus();
                          }
                        },
                        controller: xPosController,
                        cursorColor: Colors.white,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'(^\d*\.?\d*)')),
                        ],
                        style: TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                          labelText: 'X Position',
                          filled: true,
                          border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey)),
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 12,
                    ),
                    Container(
                      width: 100,
                      height: 35,
                      child: TextField(
                        onSubmitted: (val) {
                          if (onYPosUpdate != null)
                            onYPosUpdate.call(double.parse(val));
                          FocusScopeNode currentScope = FocusScope.of(context);
                          if (!currentScope.hasPrimaryFocus &&
                              currentScope.hasFocus) {
                            FocusManager.instance.primaryFocus.unfocus();
                          }
                        },
                        controller: yPosController,
                        cursorColor: Colors.white,
                        style: TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                          labelText: 'Y Position',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
