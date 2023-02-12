import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'package:function_tree/function_tree.dart';

class WaypointCard extends StatefulWidget {
  final Waypoint? waypoint;
  final String? label;
  final bool holonomicEnabled;
  final bool deleteEnabled;
  final VoidCallback onDelete;
  final VoidCallback onShouldSave;
  final VoidCallback? onPrevWaypoint;
  final VoidCallback? onNextWaypoint;
  final GlobalKey stackKey;
  final SharedPreferences prefs;

  const WaypointCard(
      {this.waypoint,
      required this.stackKey,
      this.label,
      this.holonomicEnabled = false,
      this.deleteEnabled = false,
      required this.onDelete,
      required this.onShouldSave,
      required this.prefs,
      this.onPrevWaypoint,
      this.onNextWaypoint,
      super.key});

  @override
  State<WaypointCard> createState() => _WaypointCardState();
}

class _WaypointCardState extends State<WaypointCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.waypoint == null) return Container();

    return DraggableCard(
      stackKey: widget.stackKey,
      defaultPosition: const CardPosition(top: 0, right: 0),
      prefsKey: 'waypointCardPos',
      prefs: widget.prefs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          // Override gesture detector on UI elements so they wont cause the card to move
          GestureDetector(
            onPanStart: (details) {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPositionRow(context),
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: _buildHeadingVelRow(context),
                ),
                Visibility(
                  visible: widget.holonomicEnabled,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildRotation(context),
                  ),
                ),
                Visibility(
                  visible: !widget.waypoint!.isStartPoint() &&
                      !widget.waypoint!.isEndPoint(),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildStopReversalRow(context),
                  ),
                ),
                const SizedBox(height: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

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
              color: colorScheme.onSurface,
              tooltip: widget.waypoint!.isLocked
                  ? 'Unlock Waypoint'
                  : 'Lock Waypoint',
              icon: Icon(
                widget.waypoint!.isLocked ? Icons.lock : Icons.lock_open,
              ),
              onPressed: () {
                setState(() {
                  widget.waypoint!.isLocked = !widget.waypoint!.isLocked;
                  widget.onShouldSave();
                });
              },
              splashRadius: 20,
              iconSize: 20,
              padding: const EdgeInsets.all(0),
            ),
          ),
        ),
        IconButton(
          onPressed: widget.onPrevWaypoint,
          icon: const Icon(Icons.arrow_left),
          iconSize: 20,
          splashRadius: 20,
          padding: const EdgeInsets.all(0),
          tooltip: 'Previous Waypoint',
        ),
        Text(
          widget.label ?? 'Edit Waypoint',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        IconButton(
          onPressed: widget.onNextWaypoint,
          icon: const Icon(Icons.arrow_right),
          iconSize: 20,
          splashRadius: 20,
          padding: const EdgeInsets.all(0),
          tooltip: 'Next Waypoint',
        ),
        SizedBox(
          height: 30,
          width: 30,
          child: Visibility(
            visible: widget.deleteEnabled,
            // Override gesture detector on UI elements so they wont cause the card to move
            child: GestureDetector(
              onPanStart: (details) {},
              child: IconButton(
                color: colorScheme.onSurface,
                tooltip: 'Delete Waypoint',
                icon: const Icon(
                  Icons.delete,
                ),
                onPressed: widget.onDelete,
                splashRadius: 20,
                iconSize: 20,
                padding: const EdgeInsets.all(0),
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
          width: 105,
          onSubmitted: (val) {
            if (val != null) {
              Waypoint wRef = widget.waypoint!;
              UndoRedo.addChange(_cardChange(
                () => wRef.move(val, wRef.anchorPoint.y),
                (oldVal) =>
                    wRef.move(oldVal.anchorPoint.x, oldVal.anchorPoint.y),
              ));
            }
          },
        ),
        const SizedBox(width: 12),
        _buildTextField(
          context,
          _getController(widget.waypoint!.getYPos().toStringAsFixed(2)),
          'Y Position',
          width: 105,
          onSubmitted: (val) {
            if (val != null) {
              Waypoint? wRef = widget.waypoint;
              UndoRedo.addChange(_cardChange(
                () => wRef!.move(wRef.anchorPoint.x, val),
                (oldVal) =>
                    wRef!.move(oldVal.anchorPoint.x, oldVal.anchorPoint.y),
              ));
            }
          },
        ),
      ],
    );
  }

  Widget _buildHeadingVelRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildTextField(
          context,
          _getController(
              widget.waypoint!.getHeadingDegrees().toStringAsFixed(2)),
          'Heading',
          width: 105,
          onSubmitted: (val) {
            if (val != null) {
              Waypoint? wRef = widget.waypoint;
              UndoRedo.addChange(_cardChange(
                () => wRef!.setHeading(val),
                (oldVal) => wRef!.setHeading(oldVal.getHeadingDegrees()),
              ));
            }
          },
        ),
        const SizedBox(width: 12),
        _buildTextField(
          context,
          widget.waypoint!.isReversal || widget.waypoint!.velOverride == null
              ? _getController('')
              : _getController(
                  widget.waypoint!.velOverride!.toStringAsFixed(2)),
          'Vel Override',
          enabled: !widget.waypoint!.isReversal,
          width: 105,
          onSubmitted: (val) {
            if (val == 0.0) val = null;
            Waypoint? wRef = widget.waypoint;
            UndoRedo.addChange(_cardChange(
              () => wRef!.velOverride = val,
              (oldVal) => wRef!.velOverride = oldVal.velOverride,
            ));
          },
        )
      ],
    );
  }

  Widget _buildRotation(BuildContext context) {
    return _buildTextField(
      context,
      !widget.holonomicEnabled || widget.waypoint!.holonomicAngle == null
          ? _getController('')
          : _getController(widget.waypoint!.holonomicAngle!.toStringAsFixed(2)),
      'Holonomic Rotation',
      enabled: widget.holonomicEnabled,
      onSubmitted: (val) {
        if (val != null ||
            !(widget.waypoint!.isStartPoint() ||
                widget.waypoint!.isEndPoint() ||
                widget.waypoint!.isReversal ||
                widget.waypoint!.isStopPoint)) {
          Waypoint? wRef = widget.waypoint;
          UndoRedo.addChange(_cardChange(
            () => wRef!.holonomicAngle = val,
            (oldVal) => wRef!.holonomicAngle = oldVal.holonomicAngle,
          ));
        }
      },
    );
  }

  Widget _buildStopReversalRow(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Row(
          children: [
            Checkbox(
              value: widget.waypoint!.isReversal,
              activeColor: colorScheme.primaryContainer,
              checkColor: colorScheme.onPrimaryContainer,
              onChanged: (val) {
                Waypoint? wRef = widget.waypoint;
                UndoRedo.addChange(_cardChange(
                  () => wRef!.setReversal(val!),
                  (oldVal) => wRef!.setReversal(oldVal.isReversal),
                ));
              },
            ),
            Text(
              'Reversal',
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(width: 25),
        Row(
          children: [
            Checkbox(
              value: widget.waypoint!.isStopPoint,
              activeColor: colorScheme.primaryContainer,
              checkColor: colorScheme.onPrimaryContainer,
              onChanged: (val) {
                Waypoint? wRef = widget.waypoint;
                UndoRedo.addChange(_cardChange(
                  () {
                    wRef!.isStopPoint = val!;
                    wRef.holonomicAngle ??= 0;
                  },
                  (oldVal) {
                    wRef!.isStopPoint = oldVal.isStopPoint;
                    wRef.holonomicAngle = oldVal.holonomicAngle;
                  },
                ));
              },
            ),
            Text(
              'Stop Point',
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
      BuildContext context, TextEditingController? controller, String label,
      {bool? enabled = true, ValueChanged? onSubmitted, double? width}) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: 35,
      child: TextField(
        onSubmitted: (val) {
          if (onSubmitted != null) {
            if (val.isEmpty) {
              onSubmitted(null);
            } else {
              num parsed = val.interpret();
              onSubmitted(parsed);
            }
          }
          FocusScopeNode currentScope = FocusScope.of(context);
          if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
            FocusManager.instance.primaryFocus!.unfocus();
          }
        },
        enabled: enabled,
        controller: controller,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(r'(^(-?)\d*\.?\d*)([+/\*\-](-?)\d*\.?\d*)*')),
        ],
        style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
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
          widget.onShouldSave();
        });
      },
      (oldVal) {
        setState(() {
          undo.call(oldVal);
          widget.onShouldSave();
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
