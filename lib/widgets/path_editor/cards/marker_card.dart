import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarkerCard extends StatefulWidget {
  final GlobalKey stackKey;
  final SharedPreferences? prefs;
  final EventMarker? marker;
  final double? maxMarkerPos;
  final VoidCallback? onDelete;
  final void Function(EventMarker newMarker)? onAdd;
  final VoidCallback? onSave;

  const MarkerCard(this.stackKey,
      {this.prefs,
      this.marker,
      this.maxMarkerPos,
      this.onDelete,
      this.onAdd,
      this.onSave,
      Key? key})
      : super(key: key);

  @override
  State<MarkerCard> createState() => _MarkerCardState();
}

class _MarkerCardState extends State<MarkerCard> {
  TextEditingController _nameController = TextEditingController(text: 'marker');
  TextEditingController _posController = TextEditingController(text: '0.0');

  @override
  void initState() {
    super.initState();

    if (widget.marker != null) {
      _nameController.text = widget.marker!.name;

      if (widget.maxMarkerPos != null) {
        _posController.text =
            (widget.marker!.position / widget.maxMarkerPos! * 100)
                .toStringAsFixed(2);
      }
    }

    _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nameController.text.length));
    _posController.selection = TextSelection.fromPosition(
        TextPosition(offset: _posController.text.length));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableCard(
      widget.stackKey,
      defaultPosition: CardPosition(top: 0, right: 0),
      prefsKey: 'markerCardPos',
      prefs: widget.prefs,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(),
          _buildNameField(),
          _buildPositionField(),
          _buildAddButton(),
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
          width: 30,
          height: 30,
        ),
        Text(
          widget.marker == null ? 'New Marker' : 'Edit Marker',
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(
          width: 30,
          height: 30,
          child: Visibility(
            visible: widget.marker != null,
            child: GestureDetector(
              // Override gesture detector on UI elements so they wont cause the card to move
              onPanStart: (details) {},
              child: IconButton(
                tooltip: 'Delete Marker',
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

  Widget _buildNameField() {
    return GestureDetector(
      // Override gesture detector on UI elements so they wont cause the card to move
      onPanStart: (details) {},
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Container(
          height: 35,
          child: TextField(
            onSubmitted: (value) {
              if (widget.onSave != null && widget.marker != null) {
                widget.marker!.name = value;
                widget.onSave!.call();
              }
            },
            controller: _nameController,
            cursorColor: Colors.white,
            style: TextStyle(fontSize: 14),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              labelText: 'Marker Name',
              filled: true,
              border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
              labelStyle: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionField() {
    return GestureDetector(
      // Override gesture detector on UI elements so they wont cause the card to move
      onPanStart: (details) {},
      child: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Container(
          height: 35,
          child: TextField(
            onSubmitted: (value) {
              if (widget.onSave != null &&
                  widget.marker != null &&
                  widget.maxMarkerPos != null) {
                widget.marker!.position = 0;
                if (_posController.text.length > 0) {
                  widget.marker!.position =
                      (min(100, double.parse(_posController.text)) / 100.0) *
                          widget.maxMarkerPos!;
                }
                widget.onSave!.call();
              }
            },
            controller: _posController,
            cursorColor: Colors.white,
            style: TextStyle(fontSize: 14),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)')),
            ],
            decoration: InputDecoration(
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              labelText: 'Position Percentage',
              filled: true,
              border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
              labelStyle: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      // Override gesture detector on UI elements so they wont cause the card to move
      onPanStart: (details) {},
      child: Visibility(
        visible: widget.marker == null,
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: ElevatedButton(
            onPressed: () {
              if (widget.onAdd != null &&
                  widget.marker == null &&
                  widget.maxMarkerPos != null) {
                double markerPos = 0;
                if (_posController.text.length > 0) {
                  markerPos =
                      (min(100, double.parse(_posController.text)) / 100.0) *
                          widget.maxMarkerPos!;
                }
                widget.onAdd!
                    .call(EventMarker(markerPos, _nameController.text));
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: 18,
                ),
                SizedBox(width: 4),
                Text('Add Marker'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
