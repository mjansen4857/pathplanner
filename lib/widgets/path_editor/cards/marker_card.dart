import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/widgets/custom_input_slider.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarkerCard extends StatefulWidget {
  final GlobalKey stackKey;
  final SharedPreferences prefs;
  final EventMarker? marker;
  final double maxMarkerPos;
  final VoidCallback onDelete;
  final void Function(EventMarker newMarker) onAdd;
  final void Function(EventMarker oldMarker) onEdited;

  const MarkerCard(
      {required this.stackKey,
      required this.prefs,
      this.marker,
      this.maxMarkerPos = 1,
      required this.onDelete,
      required this.onAdd,
      required this.onEdited,
      super.key});

  @override
  State<MarkerCard> createState() => _MarkerCardState();
}

class _MarkerCardState extends State<MarkerCard> {
  TextEditingController _nameController = TextEditingController(text: 'marker');
  double _sliderPos = 0;
  EventMarker? _oldMarker;

  @override
  void initState() {
    super.initState();

    if (widget.marker != null) {
      _nameController.text = widget.marker!.name;

      _sliderPos = widget.marker!.position;
    }

    _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nameController.text.length));
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return DraggableCard(
      stackKey: widget.stackKey,
      defaultPosition: CardPosition(top: 0, right: 0),
      prefsKey: 'markerCardPos',
      prefs: widget.prefs,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(colorScheme),
          _buildNameField(colorScheme),
          _buildPositionSlider(colorScheme),
          _buildAddButton(colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
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
          style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
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
                  color: colorScheme.onSurface,
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

  Widget _buildNameField(ColorScheme colorScheme) {
    return GestureDetector(
      // Override gesture detector on UI elements so they wont cause the card to move
      onPanStart: (details) {},
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
        child: Container(
          height: 35,
          child: TextField(
            onSubmitted: (value) {
              if (widget.marker != null) {
                _oldMarker = widget.marker!.clone();
                widget.marker!.name = value;
                widget.onEdited(_oldMarker!);
              }
            },
            controller: _nameController,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              labelText: 'Marker Name',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionSlider(ColorScheme colorScheme) {
    return GestureDetector(
      onPanStart: (details) {},
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
        child: InputSlider(
          onChange: (value) {
            if (widget.marker != null) {
              if (_oldMarker == null) {
                _oldMarker = widget.marker!.clone();
              }
              widget.marker!.position = value;
            }

            setState(() {
              _sliderPos = value;
            });
          },
          onChangeEnd: (value) {
            if (widget.marker != null) {
              widget.onEdited(_oldMarker!);
            }
            _oldMarker = null;
          },
          min: 0.0,
          max: widget.maxMarkerPos,
          decimalPlaces: 2,
          defaultValue: _sliderPos,
          textFieldStyle: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          inputDecoration: InputDecoration(
            contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            label: Text('Position'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          inactiveSliderColor: colorScheme.secondaryContainer,
          activeSliderColor: colorScheme.primaryContainer,
        ),
      ),
    );
  }

  Widget _buildAddButton(ColorScheme colorScheme) {
    return GestureDetector(
      // Override gesture detector on UI elements so they wont cause the card to move
      onPanStart: (details) {},
      child: Visibility(
        visible: widget.marker == null,
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              if (widget.marker == null) {
                widget.onAdd(EventMarker(_sliderPos, _nameController.text));
              }
            },
            style: ElevatedButton.styleFrom(
              primary: colorScheme.primaryContainer,
              onPrimary: colorScheme.onPrimaryContainer,
            ),
            label: const Text('Add Marker'),
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
