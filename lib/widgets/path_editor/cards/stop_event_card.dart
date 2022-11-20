import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/stop_event.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopEventCard extends StatefulWidget {
  final GlobalKey stackKey;
  final SharedPreferences prefs;
  final StopEvent? stopEvent;
  final void Function(StopEvent oldEvent) onEdited;

  const StopEventCard({
    required this.stackKey,
    required this.prefs,
    required this.stopEvent,
    required this.onEdited,
    super.key,
  });

  @override
  State<StopEventCard> createState() => _StopEventCardState();
}

class _StopEventCardState extends State<StopEventCard> {
  StopEvent? _oldEvent;

  @override
  Widget build(BuildContext context) {
    if (widget.stopEvent == null) {
      return Container();
    }

    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return DraggableCard(
      stackKey: widget.stackKey,
      defaultPosition: const CardPosition(top: 0, right: 0),
      prefsKey: 'stopEventCardPos',
      prefs: widget.prefs,
      child: Column(
        children: [
          Text(
            'AutoBuilder Stop Event',
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          _buildNameFields(),
        ],
      ),
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
            for (int i = 0; i < widget.stopEvent!.eventNames.length; i++)
              _buildNameTextField(
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _oldEvent = widget.stopEvent!.clone();
                        widget.stopEvent!.eventNames[i] = value;
                        widget.onEdited(_oldEvent!);
                      });
                    } else if (widget.stopEvent!.eventNames.length > 1) {
                      setState(() {
                        _oldEvent = widget.stopEvent!.clone();
                        widget.stopEvent!.eventNames.removeAt(i);
                        widget.onEdited(_oldEvent!);
                      });
                    } else {
                      // Hack to get name to show back up when enter pressed on empty text box
                      setState(() {});
                    }
                  },
                  name: widget.stopEvent!.eventNames[i],
                  label: 'Event ${i + 1}'),
            if (widget.stopEvent!.eventNames.length < 8)
              _buildNameTextField(
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _oldEvent = widget.stopEvent!.clone();
                      widget.stopEvent!.eventNames.add(value);
                      widget.onEdited(_oldEvent!);
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
}
