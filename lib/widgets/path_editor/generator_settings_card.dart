import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';

class GeneratorSettingsCard extends StatefulWidget {
  final RobotPath? path;
  final VoidCallback? onShouldSave;
  final void Function(Offset, Size)? onDragged;
  final VoidCallback? onDragFinished;

  GeneratorSettingsCard(this.path,
      {this.onShouldSave, this.onDragged, this.onDragFinished});

  @override
  _GeneratorSettingsCardState createState() => _GeneratorSettingsCardState();
}

class _GeneratorSettingsCardState extends State<GeneratorSettingsCard> {
  Offset? _dragStartLocal;
  GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (widget.path == null) return Container();

    return GestureDetector(
      key: _key,
      onPanStart: (DragStartDetails details) {
        _dragStartLocal = details.localPosition;
      },
      onPanEnd: (DragEndDetails details) {
        _dragStartLocal = null;
        if (widget.onDragFinished != null) {
          widget.onDragFinished!.call();
        }
      },
      onPanUpdate: (DragUpdateDetails details) {
        if (widget.onDragged != null && _dragStartLocal != null) {
          RenderBox renderBox =
              _key.currentContext?.findRenderObject() as RenderBox;
          widget.onDragged!
              .call(details.globalPosition - _dragStartLocal!, renderBox.size);
        }
      },
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Container(
          width: 250,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: Colors.white.withOpacity(0.13),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Generator Settings'),
                        ],
                      ),
                      SizedBox(height: 12),
                      // Override gesture detector on UI elements so they wont cause the card to move
                      GestureDetector(
                        onPanStart: (details) {},
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                _buildTextField(
                                  context,
                                  widget.path!.maxVelocity != null
                                      ? _getController(widget.path!.maxVelocity!
                                          .toStringAsFixed(2))
                                      : _getController('8.0'),
                                  'Max Velocity',
                                  onSubmitted: (val) {
                                    setState(() {
                                      widget.path!.maxVelocity = val;
                                      if (widget.onShouldSave != null) {
                                        widget.onShouldSave!.call();
                                      }
                                    });
                                  },
                                ),
                                SizedBox(width: 12),
                                _buildTextField(
                                  context,
                                  widget.path!.maxAcceleration != null
                                      ? _getController(widget
                                          .path!.maxAcceleration!
                                          .toStringAsFixed(2))
                                      : _getController('5.0'),
                                  'Max Accel',
                                  onSubmitted: (val) {
                                    setState(() {
                                      widget.path!.maxAcceleration = val;
                                      if (widget.onShouldSave != null) {
                                        widget.onShouldSave!.call();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: widget.path!.isReversed ?? false,
                                      activeColor: Colors.indigo,
                                      onChanged: (val) {
                                        setState(() {
                                          widget.path!.isReversed = val;
                                          if (widget.onShouldSave != null) {
                                            widget.onShouldSave!.call();
                                          }
                                        });
                                      },
                                    ),
                                    SizedBox(width: 4),
                                    Text('Reversed'),
                                    SizedBox(width: 12),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
            var parsed = double.tryParse(val)!;
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

  TextEditingController _getController(String text) {
    return TextEditingController(text: text)
      ..selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
  }
}
