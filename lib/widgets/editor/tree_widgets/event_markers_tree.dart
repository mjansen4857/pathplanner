import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:undo/undo.dart';

class EventMarkersTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ValueChanged<int?>? onMarkerHovered;
  final ValueChanged<int?>? onMarkerSelected;
  final int? initiallySelectedMarker;
  final ChangeStack undoStack;

  const EventMarkersTree({
    super.key,
    required this.path,
    this.onPathChanged,
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
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              elevation: 4.0,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add New Marker'),
            onPressed: () {
              widget.undoStack.add(Change(
                PathPlannerPath.cloneEventMarkers(markers),
                () {
                  markers.add(EventMarker.defaultMarker());
                  widget.onPathChanged?.call();
                },
                (oldValue) {
                  _selectedMarker = null;
                  widget.onMarkerHovered?.call(null);
                  widget.onMarkerSelected?.call(null);
                  widget.path.eventMarkers =
                      PathPlannerPath.cloneEventMarkers(oldValue);
                  widget.onPathChanged?.call();
                },
              ));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMarkerCard(int markerIdx) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return TreeCardNode(
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
                  widget.onPathChanged?.call();
                },
                (oldValue) {
                  markers[markerIdx].name = oldValue;
                  widget.onPathChanged?.call();
                },
              ));
            },
          ),
          Expanded(child: Container()),
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
                    widget.onPathChanged?.call();
                  },
                  (oldValue) {
                    widget.path.eventMarkers =
                        PathPlannerPath.cloneEventMarkers(oldValue);
                    widget.onMarkerSelected?.call(null);
                    widget.onMarkerHovered?.call(null);
                    widget.onPathChanged?.call();
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
        Slider(
          value: markers[markerIdx].waypointRelativePos.toDouble(),
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
                widget.onPathChanged?.call();
              },
              (oldValue) {
                markers[markerIdx].waypointRelativePos = oldValue;
                widget.onPathChanged?.call();
              },
            ));
          },
          onChanged: (value) {
            markers[markerIdx].waypointRelativePos = value;
            widget.onPathChanged?.call();
          },
        ),
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
          onUpdated: widget.onPathChanged,
          onGroupTypeChanged: (value) {
            widget.undoStack.add(Change(
              command.type,
              () {
                List<Command> cmds = command.commands;
                markers[markerIdx].command =
                    Command.fromType(value, commands: cmds) as CommandGroup;
                widget.onPathChanged?.call();
              },
              (oldValue) {
                List<Command> cmds = command.commands;
                markers[markerIdx].command =
                    Command.fromType(oldValue, commands: cmds) as CommandGroup;
                widget.onPathChanged?.call();
              },
            ));
          },
        ),
      ),
    );
  }
}
