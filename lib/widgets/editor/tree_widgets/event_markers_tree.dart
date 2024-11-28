import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';
import 'package:pathplanner/widgets/editor/info_card.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/add_command_button.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/named_command_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/item_count.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class EventMarkersTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChangedNoSim;
  final ValueChanged<int?>? onMarkerHovered;
  final ValueChanged<int?>? onMarkerSelected;
  final int? initiallySelectedMarker;
  final ChangeStack undoStack;

  const EventMarkersTree({
    super.key,
    required this.path,
    this.onPathChangedNoSim,
    this.onMarkerHovered,
    this.onMarkerSelected,
    this.initiallySelectedMarker,
    required this.undoStack,
  });

  @override
  State<EventMarkersTree> createState() => _EventMarkersTreeState();
}

class _EventMarkersTreeState extends State<EventMarkersTree> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<EventMarker> get markers => widget.path.eventMarkers;
  List<Waypoint> get waypoints => widget.path.waypoints;

  late List<ExpansionTileController> _controllers;
  int? _selectedMarker;

  double _sliderChangeStart = 0;

  @override
  void initState() {
    super.initState();

    _selectedMarker = widget.initiallySelectedMarker;

    _controllers =
        List.generate(markers.length, (index) => ExpansionTileController());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Event Markers'),
      leading: const Icon(Icons.pin_drop_rounded),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {
              widget.undoStack.add(Change(
                PathPlannerPath.cloneEventMarkers(markers),
                () {
                  markers.add(EventMarker());
                  widget.onPathChangedNoSim?.call();
                },
                (oldValue) {
                  _selectedMarker = null;
                  widget.onMarkerHovered?.call(null);
                  widget.onMarkerSelected?.call(null);
                  widget.path.eventMarkers =
                      PathPlannerPath.cloneEventMarkers(oldValue);
                  widget.onPathChangedNoSim?.call();
                },
              ));
            },
            tooltip: 'Add New Event Marker',
          ),
          const SizedBox(width: 8),
          ItemCount(count: widget.path.eventMarkers.length),
        ],
      ),
      initiallyExpanded: widget.path.eventMarkersExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          widget.path.eventMarkersExpanded = value;
          if (value == false) {
            _selectedMarker = null;
            widget.onMarkerSelected?.call(null);
          }
        }
      },
      elevation: 1.0,
      children: [
        for (int i = 0; i < markers.length; i++) _buildMarkerCard(i),
      ],
    );
  }

  Widget _buildMarkerCard(int markerIdx) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return TreeCardNode(
      leading: const Icon(Icons.pin_drop_rounded),
      controller: _controllers[markerIdx],
      onHoverStart: () => widget.onMarkerHovered?.call(markerIdx),
      onHoverEnd: () => widget.onMarkerHovered?.call(null),
      onExpansionChanged: (expanded) {
        if (expanded ?? false) {
          if (_selectedMarker != null) {
            _controllers[_selectedMarker!].collapse();
          }
          _selectedMarker = markerIdx;
          widget.onMarkerSelected?.call(markerIdx);
        } else {
          if (markerIdx == _selectedMarker) {
            _selectedMarker = null;
            widget.onMarkerSelected?.call(null);
          }
        }
      },
      title: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                hint: const Text('Event Name'),
                value: markers[markerIdx].name.isEmpty
                    ? null
                    : markers[markerIdx].name,
                items: ProjectPage.events.isEmpty
                    ? [
                        // Workaround to prevent menu from disabling itself with empty items list
                        DropdownMenuItem(
                          value: '',
                          enabled: false,
                          child: Text(
                            '',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ]
                    : [
                        for (String event in ProjectPage.events)
                          if (event.isNotEmpty)
                            DropdownMenuItem(
                              value: event,
                              child: Text(
                                event,
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                      ],
                buttonStyleData: ButtonStyleData(
                  padding: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  height: 42,
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  isOverButton: true,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                menuItemStyleData: const MenuItemStyleData(),
                dropdownSearchData: DropdownSearchData(
                  searchController: _controller,
                  searchInnerWidgetHeight: 42,
                  searchInnerWidget: Container(
                    height: 46,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: TextFormField(
                      focusNode: _focusNode,
                      autofocus: true,
                      controller: _controller,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        hintText: 'Search or add new...',
                        hintStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onFieldSubmitted: (value) {
                        Navigator.of(context).pop();

                        if (value.isNotEmpty) {
                          widget.undoStack.add(Change(
                            markers[markerIdx].name,
                            () {
                              markers[markerIdx].name = value;
                              ProjectPage.events.add(value);
                              widget.onPathChangedNoSim?.call();
                            },
                            (oldValue) {
                              markers[markerIdx].name = oldValue;
                              widget.onPathChangedNoSim?.call();
                            },
                          ));
                        }
                      },
                    ),
                  ),
                  searchMatchFn: (item, searchValue) {
                    return item.value
                        .toString()
                        .toLowerCase()
                        .startsWith(searchValue.toLowerCase());
                  },
                ),
                onMenuStateChange: (isOpen) {
                  if (!isOpen) {
                    _controller.clear();
                  } else {
                    // Request focus after a delay to wait for the menu to open
                    Future.delayed(const Duration(milliseconds: 50))
                        .then((_) => _focusNode.requestFocus());
                  }
                },
                onChanged: (value) {
                  if (value != null && value.isNotEmpty) {
                    widget.undoStack.add(Change(
                      markers[markerIdx].name,
                      () {
                        markers[markerIdx].name = value;
                        widget.onPathChangedNoSim?.call();
                      },
                      (oldValue) {
                        markers[markerIdx].name = oldValue;
                        widget.onPathChangedNoSim?.call();
                      },
                    ));
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          InfoCard(
              value: markers[markerIdx].endWaypointRelativePos == null
                  ? markers[markerIdx].waypointRelativePos.toStringAsFixed(2)
                  : '${markers[markerIdx].waypointRelativePos.toStringAsFixed(2)}-${markers[markerIdx].endWaypointRelativePos!.toStringAsFixed(2)}'),
          Tooltip(
            message: 'Delete Marker',
            waitDuration: const Duration(seconds: 1),
            child: IconButton(
              icon: const Icon(Icons.delete_forever),
              color: colorScheme.error,
              onPressed: () {
                widget.undoStack.add(Change(
                  PathPlannerPath.cloneEventMarkers(widget.path.eventMarkers),
                  () {
                    markers.removeAt(markerIdx);
                    widget.onMarkerSelected?.call(null);
                    widget.onMarkerHovered?.call(null);
                    widget.onPathChangedNoSim?.call();
                  },
                  (oldValue) {
                    widget.path.eventMarkers =
                        PathPlannerPath.cloneEventMarkers(oldValue);
                    widget.onMarkerSelected?.call(null);
                    widget.onMarkerHovered?.call(null);
                    widget.onPathChangedNoSim?.call();
                  },
                ));
              },
            ),
          ),
        ],
      ),
      initiallyExpanded: markerIdx == _selectedMarker,
      elevation: 4.0,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: Row(
            children: [
              Checkbox(
                value: markers[markerIdx].isZoned,
                onChanged: (value) {
                  widget.undoStack.add(Change(
                    markers[markerIdx].endWaypointRelativePos,
                    () {
                      setState(() {
                        markers[markerIdx].endWaypointRelativePos =
                            (value ?? false)
                                ? markers[markerIdx].waypointRelativePos
                                : null;
                      });
                      widget.onPathChangedNoSim?.call();
                    },
                    (oldValue) {
                      setState(() {
                        markers[markerIdx].endWaypointRelativePos = oldValue;
                      });
                      widget.onPathChangedNoSim?.call();
                    },
                  ));
                },
              ),
              const SizedBox(width: 4),
              const Text(
                'Zoned Event',
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: markers[markerIdx].waypointRelativePos.toDouble(),
                secondaryTrackValue:
                    markers[markerIdx].endWaypointRelativePos?.toDouble(),
                min: 0.0,
                max: waypoints.length - 1.0,
                label:
                    markers[markerIdx].waypointRelativePos.toStringAsFixed(2),
                onChangeStart: (value) {
                  _sliderChangeStart = value;
                },
                onChangeEnd: (value) {
                  widget.undoStack.add(Change(
                    _sliderChangeStart,
                    () {
                      markers[markerIdx].waypointRelativePos = value;
                      widget.onPathChangedNoSim?.call();
                    },
                    (oldValue) {
                      markers[markerIdx].waypointRelativePos = oldValue;
                      widget.onPathChangedNoSim?.call();
                    },
                  ));
                },
                onChanged: (value) {
                  if (!markers[markerIdx].isZoned ||
                      value <= markers[markerIdx].endWaypointRelativePos!) {
                    setState(() {
                      markers[markerIdx].waypointRelativePos = value;
                      widget.onPathChangedNoSim?.call();
                    });
                  }
                },
              ),
            ),
            SizedBox(
              width: 75,
              child: NumberTextField(
                initialValue: markers[markerIdx].waypointRelativePos,
                precision: 2,
                label: markers[markerIdx].isZoned ? 'Start Pos' : 'Position',
                onSubmitted: (value) {
                  if (value != null) {
                    final maxVal = markers[markerIdx].isZoned
                        ? markers[markerIdx].endWaypointRelativePos!
                        : (waypoints.length - 1);
                    final val = MathUtil.clamp(value, 0.0, maxVal);
                    widget.undoStack.add(Change(
                      markers[markerIdx].waypointRelativePos,
                      () {
                        markers[markerIdx].waypointRelativePos = val;
                        widget.onPathChangedNoSim?.call();
                      },
                      (oldValue) {
                        markers[markerIdx].waypointRelativePos = oldValue;
                        widget.onPathChangedNoSim?.call();
                      },
                    ));
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        const SizedBox(height: 8),
        if (markers[markerIdx].isZoned) ...[
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: markers[markerIdx].endWaypointRelativePos!.toDouble(),
                  min: 0.0,
                  max: waypoints.length - 1.0,
                  label: markers[markerIdx]
                      .endWaypointRelativePos!
                      .toStringAsFixed(2),
                  onChangeStart: (value) {
                    _sliderChangeStart = value;
                  },
                  onChangeEnd: (value) {
                    widget.undoStack.add(Change(
                      _sliderChangeStart,
                      () {
                        markers[markerIdx].endWaypointRelativePos = value;
                        widget.onPathChangedNoSim?.call();
                      },
                      (oldValue) {
                        markers[markerIdx].endWaypointRelativePos = oldValue;
                        widget.onPathChangedNoSim?.call();
                      },
                    ));
                  },
                  onChanged: (value) {
                    if (value >= markers[markerIdx].waypointRelativePos) {
                      setState(() {
                        markers[markerIdx].endWaypointRelativePos = value;
                        widget.onPathChangedNoSim?.call();
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: 75,
                child: NumberTextField(
                  initialValue: markers[markerIdx].endWaypointRelativePos!,
                  precision: 2,
                  label: 'End Pos',
                  onSubmitted: (value) {
                    if (value != null) {
                      final minVal = markers[markerIdx].waypointRelativePos;
                      final val =
                          MathUtil.clamp(value, minVal, waypoints.length - 1);
                      widget.undoStack.add(Change(
                        markers[markerIdx].endWaypointRelativePos,
                        () {
                          markers[markerIdx].endWaypointRelativePos = val;
                          widget.onPathChangedNoSim?.call();
                        },
                        (oldValue) {
                          markers[markerIdx].endWaypointRelativePos = oldValue;
                          widget.onPathChangedNoSim?.call();
                        },
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const Divider(),
        if (markers[markerIdx].command != null) _buildCommandCard(markerIdx),
        if (markers[markerIdx].command == null)
          Center(
            child: AddCommandButton(
              allowPathCommand: false,
              allowWaitCommand: false,
              onTypeChosen: (value) {
                widget.undoStack.add(Change(
                  null,
                  () {
                    markers[markerIdx].command = Command.fromType(value);
                    widget.onPathChangedNoSim?.call();
                  },
                  (oldValue) {
                    markers[markerIdx].command = null;
                    widget.onPathChangedNoSim?.call();
                  },
                ));
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCommandCard(int markerIdx) {
    assert(markers[markerIdx].command != null);

    Command command = markers[markerIdx].command!;

    if (command is NamedCommand) {
      return Card(
        elevation: 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: NamedCommandWidget(
            command: command,
            undoStack: widget.undoStack,
            onUpdated: widget.onPathChangedNoSim,
            onRemoved: () => _addRemoveCommandChange(markerIdx),
          ),
        ),
      );
    } else if (command is CommandGroup) {
      return Card(
        elevation: 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CommandGroupWidget(
            command: command,
            undoStack: widget.undoStack,
            onUpdated: widget.onPathChangedNoSim,
            onRemoved: () => _addRemoveCommandChange(markerIdx),
            onGroupTypeChanged: (value) {
              widget.undoStack.add(Change(
                command.type,
                () {
                  List<Command> cmds = command.commands;
                  markers[markerIdx].command =
                      Command.fromType(value, commands: cmds) as CommandGroup;
                  widget.onPathChangedNoSim?.call();
                },
                (oldValue) {
                  List<Command> cmds = command.commands;
                  markers[markerIdx].command =
                      Command.fromType(oldValue, commands: cmds)
                          as CommandGroup;
                  widget.onPathChangedNoSim?.call();
                },
              ));
            },
          ),
        ),
      );
    }

    // Shouldn't get here
    return Container();
  }

  void _addRemoveCommandChange(int markerIdx) {
    widget.undoStack.add(Change(
      markers[markerIdx].command?.clone(),
      () {
        markers[markerIdx].command = null;
        widget.onPathChangedNoSim?.call();
      },
      (oldValue) {
        markers[markerIdx].command = oldValue?.clone();
        widget.onPathChangedNoSim?.call();
      },
    ));
  }
}
