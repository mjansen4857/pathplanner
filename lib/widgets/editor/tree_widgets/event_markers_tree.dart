import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/command_card.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/renamable_title.dart';

class EventMarkersTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ValueChanged<int?>? onMarkerHovered;
  final ValueChanged<int?>? onMarkerSelected;
  final int? initiallySelectedMarker;

  const EventMarkersTree({
    super.key,
    required this.path,
    this.onPathChanged,
    this.onMarkerHovered,
    this.onMarkerSelected,
    this.initiallySelectedMarker,
  });

  @override
  State<EventMarkersTree> createState() => _EventMarkersTreeState();
}

class _EventMarkersTreeState extends State<EventMarkersTree> {
  List<EventMarker> get markers => widget.path.eventMarkers;
  List<Waypoint> get waypoints => widget.path.waypoints;

  late List<ExpansionTileController> _controllers;
  int? _selectedMarker;

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
          widget.onPathChanged?.call();
        }
      },
      elevation: 1.0,
      children: [
        for (int i = 0; i < markers.length; i++) _buildMarkerCard(i),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add New Marker'),
            onPressed: () {
              markers.add(EventMarker.defaultMarker());
              widget.onPathChanged?.call();
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
              markers[markerIdx].name = value;
              widget.onPathChanged?.call();
            },
          ),
          Expanded(child: Container()),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            color: colorScheme.error,
            onPressed: () {
              markers.removeAt(markerIdx);
              if (_selectedMarker == markerIdx) {
                widget.onMarkerSelected?.call(null);
              }
              widget.onMarkerHovered?.call(null);
              widget.onPathChanged?.call();
            },
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
          onChanged: (value) {
            markers[markerIdx].waypointRelativePos = value;
            widget.onPathChanged?.call();
          },
        ),
        CommandCard(
          command: markers[markerIdx].command,
          onCommandChanged: (cmd) {
            markers[markerIdx].command = cmd;
            widget.onPathChanged?.call();
          },
        ),
      ],
    );
  }
}
