import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/services/generator/trajectory.dart';
import 'package:pathplanner/widgets/custom_input_slider.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarkerCard extends StatefulWidget {
  final GlobalKey stackKey;
  final SharedPreferences prefs;
  final RobotPath path;
  final EventMarker? marker;
  final double maxMarkerPos;
  final VoidCallback onDelete;
  final void Function(EventMarker newMarker) onAdd;
  final void Function(EventMarker oldMarker) onEdited;
  final ValueChanged<double?> onPreviewPosChanged;
  final VoidCallback? onPrevMarker;
  final VoidCallback? onNextMarker;

  const MarkerCard(
      {required this.stackKey,
      required this.prefs,
      required this.path,
      this.marker,
      this.maxMarkerPos = 1,
      required this.onDelete,
      required this.onAdd,
      required this.onEdited,
      required this.onPreviewPosChanged,
      this.onPrevMarker,
      this.onNextMarker,
      super.key});

  @override
  State<MarkerCard> createState() => _MarkerCardState();
}

class _MarkerCardState extends State<MarkerCard> {
  double _sliderPos = 0;
  EventMarker? _oldMarker;

  @override
  void initState() {
    super.initState();

    if (widget.marker != null) {
      _sliderPos = widget.marker!.position;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableCard(
      stackKey: widget.stackKey,
      defaultPosition: const CardPosition(top: 0, right: 0),
      prefsKey: 'markerCardPos',
      prefs: widget.prefs,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(),
          if (widget.marker != null) _buildNameFields(),
          _buildPositionSlider(),
          _buildAddButton(),
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
        const SizedBox(
          width: 30,
          height: 30,
        ),
        if (widget.marker != null)
          IconButton(
            onPressed: widget.onPrevMarker,
            icon: const Icon(Icons.arrow_left),
            iconSize: 20,
            splashRadius: 20,
            padding: const EdgeInsets.all(0),
            tooltip: 'Previous Marker',
          ),
        Text(
          widget.marker == null ? 'New Marker' : 'Edit Marker',
          style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
        ),
        if (widget.marker != null)
          IconButton(
            onPressed: widget.onNextMarker,
            icon: const Icon(Icons.arrow_right),
            iconSize: 20,
            splashRadius: 20,
            padding: const EdgeInsets.all(0),
            tooltip: 'Next Marker',
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
                padding: const EdgeInsets.all(0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameFields() {
    return GestureDetector(
      // Override gesture detector on UI elements so they wont cause the card to move
      onPanStart: (details) {},
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
        child: Column(
          children: [
            for (int i = 0; i < widget.marker!.names.length; i++)
              _buildNameTextField(
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _oldMarker = widget.marker!.clone();
                        widget.marker!.names[i] = value;
                        widget.onEdited(_oldMarker!);
                      });
                    } else if (widget.marker!.names.length > 1) {
                      setState(() {
                        _oldMarker = widget.marker!.clone();
                        widget.marker!.names.removeAt(i);
                        widget.onEdited(_oldMarker!);
                      });
                    } else {
                      // Hack to get name to show back up when enter pressed on empty text box
                      setState(() {});
                    }
                  },
                  name: widget.marker!.names[i],
                  label: 'Event ${i + 1}'),
            if (widget.marker!.names.length < 4)
              _buildNameTextField(
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _oldMarker = widget.marker!.clone();
                      widget.marker!.names.add(value);
                      widget.onEdited(_oldMarker!);
                    });
                  }
                },
                name: '',
                label: 'Add new event...',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameTextField(
      {required ValueChanged<String> onSubmitted,
      required String label,
      required String name}) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextEditingController controller = TextEditingController(text: name);
    controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        height: 35,
        child: TextField(
          onSubmitted: onSubmitted,
          controller: controller,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionSlider() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onPanStart: (details) {},
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: InputSlider(
          onChange: (value) {
            if (widget.marker != null) {
              _oldMarker ??= widget.marker!.clone();
              widget.marker!.position = value;
              Trajectory.calculateMarkerTime(
                  widget.path.generatedTrajectory, widget.marker!);
            } else {
              widget.onPreviewPosChanged(value);
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
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            label: const Text('Position'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          inactiveSliderColor: colorScheme.secondaryContainer,
          activeSliderColor: colorScheme.primaryContainer,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

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
                widget.onAdd(EventMarker(_sliderPos, ['event']));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              minimumSize: const Size(220, 40),
            ),
            label: const Text('Add Marker'),
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
