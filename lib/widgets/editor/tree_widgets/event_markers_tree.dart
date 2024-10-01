import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/editor/info_card.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/item_count.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
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
                  markers.add(EventMarker.defaultMarker());
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
          RenamableTitle(
            title: markers[markerIdx].name,
            onRename: (value) {
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
            },
          ),
          Expanded(child: Container()),
          const SizedBox(width: 12),
          InfoCard(
              value:
                  'Positioned at ${markers[markerIdx].waypointRelativePos.toStringAsFixed(2)}'),
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
                      markers[markerIdx].endWaypointRelativePos =
                          (value ?? false)
                              ? markers[markerIdx].waypointRelativePos
                              : null;
                      widget.onPathChangedNoSim?.call();
                    },
                    (oldValue) {
                      markers[markerIdx].endWaypointRelativePos = oldValue;
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
        Slider(
          value: markers[markerIdx].waypointRelativePos.toDouble(),
          secondaryTrackValue:
              markers[markerIdx].endWaypointRelativePos?.toDouble(),
          min: 0.0,
          max: waypoints.length - 1.0,
          divisions: (waypoints.length - 1) * 20,
          label: markers[markerIdx].waypointRelativePos.toStringAsFixed(2),
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
        const SizedBox(height: 12),
        if (markers[markerIdx].isZoned) ...[
          Slider(
            value: markers[markerIdx].endWaypointRelativePos!.toDouble(),
            min: 0.0,
            max: waypoints.length - 1.0,
            divisions: (waypoints.length - 1) * 20,
            label:
                markers[markerIdx].endWaypointRelativePos!.toStringAsFixed(2),
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
          const SizedBox(height: 12),
        ],
        const Divider(),
        _buildCommandCard(markerIdx),
      ],
    );
  }

  Widget _buildCommandCard(int markerIdx) {
    CommandGroup command = markers[markerIdx].command;
    return Card(
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CommandGroupWidget(
          command: command,
          removable: false,
          undoStack: widget.undoStack,
          onUpdated: widget.onPathChangedNoSim,
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
                    Command.fromType(oldValue, commands: cmds) as CommandGroup;
                widget.onPathChangedNoSim?.call();
              },
            ));
          },
        ),
      ),
    );
  }
}
