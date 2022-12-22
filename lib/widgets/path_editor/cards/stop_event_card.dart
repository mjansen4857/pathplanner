import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:function_tree/function_tree.dart';
import 'package:pathplanner/robot_path/stop_event.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopEventCard extends StatefulWidget {
  final GlobalKey stackKey;
  final SharedPreferences prefs;
  final StopEvent? stopEvent;
  final void Function(StopEvent oldEvent) onEdited;
  final VoidCallback? onPrevStopEvent;
  final VoidCallback? onNextStopEvent;

  const StopEventCard({
    required this.stackKey,
    required this.prefs,
    required this.stopEvent,
    required this.onEdited,
    this.onPrevStopEvent,
    this.onNextStopEvent,
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

    return DraggableCard(
      stackKey: widget.stackKey,
      defaultPosition: const CardPosition(top: 0, right: 0),
      prefsKey: 'stopEventCardPos',
      prefs: widget.prefs,
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildExecutionBehaviorDropdown(),
          _buildNameFields(),
          const SizedBox(height: 8),
          _buildWaitBehaviorDropdown(),
          if (widget.stopEvent!.waitBehavior != WaitBehavior.none)
            _buildWaitTime(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.stopEvent != null)
          IconButton(
            onPressed: widget.onPrevStopEvent,
            icon: const Icon(Icons.arrow_left),
            iconSize: 20,
            splashRadius: 20,
            padding: const EdgeInsets.all(0),
            tooltip: 'Previous Stop Event',
          ),
        const Text(
          'Edit Stop Event',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        if (widget.stopEvent != null)
          IconButton(
            onPressed: widget.onNextStopEvent,
            icon: const Icon(Icons.arrow_right),
            iconSize: 20,
            splashRadius: 20,
            padding: const EdgeInsets.all(0),
            tooltip: 'Next Stop Event',
          ),
      ],
    );
  }

  Widget _buildWaitTime(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 8, 3, 0),
      child: _buildTextField(
        context,
        _getController(widget.stopEvent!.waitTime.toStringAsFixed(2)),
        'Wait Time',
        onSubmitted: (val) {
          setState(() {
            _oldEvent = widget.stopEvent!.clone();
            widget.stopEvent!.waitTime = val ?? 0;
            widget.onEdited(_oldEvent!);
          });
        },
      ),
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

  TextEditingController _getController(String text) {
    return TextEditingController(text: text)
      ..selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
  }

  Widget _buildWaitBehaviorDropdown() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wait Behavior:'),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: ExcludeFocus(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<WaitBehavior>(
                      dropdownColor: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      value: widget.stopEvent!.waitBehavior,
                      isExpanded: true,
                      underline: Container(),
                      icon: const Icon(Icons.arrow_drop_down),
                      onChanged: (WaitBehavior? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _oldEvent = widget.stopEvent!.clone();
                            widget.stopEvent!.waitBehavior = newValue;
                            widget.onEdited(_oldEvent!);
                          });
                        }
                      },
                      items: [
                        ...WaitBehavior.values
                            .map<DropdownMenuItem<WaitBehavior>>(
                                (WaitBehavior value) {
                          return DropdownMenuItem<WaitBehavior>(
                            value: value,
                            child: Text(
                                '${value.name[0].toUpperCase()}${value.name.substring(1)}'),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionBehaviorDropdown() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Execution Behavior:'),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: ExcludeFocus(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<ExecutionBehavior>(
                      dropdownColor: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      value: widget.stopEvent!.executionBehavior,
                      isExpanded: true,
                      underline: Container(),
                      icon: const Icon(Icons.arrow_drop_down),
                      onChanged: (ExecutionBehavior? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _oldEvent = widget.stopEvent!.clone();
                            widget.stopEvent!.executionBehavior = newValue;
                            widget.onEdited(_oldEvent!);
                          });
                        }
                      },
                      items: [
                        ...ExecutionBehavior.values
                            .map<DropdownMenuItem<ExecutionBehavior>>(
                                (ExecutionBehavior value) {
                          return DropdownMenuItem<ExecutionBehavior>(
                            value: value,
                            child: Text(
                                '${value.name[0].toUpperCase()}${value.name.substring(1)}'),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                    } else if (widget.stopEvent!.eventNames.isNotEmpty) {
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
                  label: _getEventLabel(i)),
            if (widget.stopEvent!.eventNames.length < 4)
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

  String _getEventLabel(int index) {
    if (widget.stopEvent!.executionBehavior ==
        ExecutionBehavior.parallelDeadline) {
      if (index == 0) return 'Deadline Event';

      return 'Event $index';
    }

    return 'Event ${index + 1}';
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
