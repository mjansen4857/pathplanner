import 'package:flutter/material.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditorSettingsTree extends StatefulWidget {
  final bool initiallyExpanded;

  const EditorSettingsTree({
    super.key,
    this.initiallyExpanded = false,
  });

  @override
  State<EditorSettingsTree> createState() => _EditorSettingsTreeState();
}

class _EditorSettingsTreeState extends State<EditorSettingsTree> {
  late SharedPreferences _prefs;
  bool _snapToGuidelines = Defaults.snapToGuidelines;
  bool _hidePathsOnHover = Defaults.hidePathsOnHover;
  bool _showStates = Defaults.showStates;
  bool _showRobotDetails = Defaults.showRobotDetails;
  bool _showGrid = Defaults.showGrid;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((value) {
      setState(() {
        _prefs = value;
        _snapToGuidelines = _prefs.getBool(PrefsKeys.snapToGuidelines) ??
            Defaults.snapToGuidelines;
        _hidePathsOnHover = _prefs.getBool(PrefsKeys.hidePathsOnHover) ??
            Defaults.hidePathsOnHover;
        _showStates =
            _prefs.getBool(PrefsKeys.showStates) ?? Defaults.showStates;
        _showRobotDetails = _prefs.getBool(PrefsKeys.showRobotDetails) ??
            Defaults.showRobotDetails;
        _showGrid = _prefs.getBool(PrefsKeys.showGrid) ?? Defaults.showGrid;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      initiallyExpanded: widget.initiallyExpanded,
      title: const Text('Editor Settings'),
      leading: const Icon(Icons.settings),
      elevation: 1.0,
      children: [
        _buildCheckboxRow(
          'Snap To Guidelines',
          _snapToGuidelines,
          _updateSnapToGuidelines,
          'Enable or disable snapping to guidelines.',
        ),
        _buildCheckboxRow(
          'Hide Other Paths on Hover',
          _hidePathsOnHover,
          _updateHidePathsOnHover,
          'Hide other paths when hovering over a specific path.',
        ),
        _buildCheckboxRow(
          'Show Trajectory States',
          _showStates,
          _updateShowStates,
          'Display trajectory states.',
        ),
        _buildCheckboxRow(
          'Show Robot Details',
          _showRobotDetails,
          _updateShowRobotDetails,
          'Display additional details about the robot\'s current rotation and position.',
        ),
        _buildCheckboxRow(
          'Show Grid',
          _showGrid,
          _updateShowGrid,
          'Toggle the visibility of the grid on the field. Each cell is 0.5M x 0.5M.',
        ),
      ],
    );
  }

  Widget _buildCheckboxRow(
      String label, bool value, Function(bool) onChanged, String tooltip) {
    return Row(
      children: [
        Tooltip(
          message: tooltip,
          child: Checkbox(
            value: value,
            onChanged: (val) => onChanged(val!),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            bottom: 3.0,
            left: 4.0,
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }

  void _updateSnapToGuidelines(bool value) {
    setState(() {
      _snapToGuidelines = value;
    });
    _prefs.setBool(PrefsKeys.snapToGuidelines, _snapToGuidelines);
  }

  void _updateHidePathsOnHover(bool value) {
    setState(() {
      _hidePathsOnHover = value;
    });
    _prefs.setBool(PrefsKeys.hidePathsOnHover, _hidePathsOnHover);
  }

  void _updateShowStates(bool value) {
    setState(() {
      _showStates = value;
    });
    _prefs.setBool(PrefsKeys.showStates, _showStates);
  }

  void _updateShowRobotDetails(bool value) {
    setState(() {
      _showRobotDetails = value;
    });
    _prefs.setBool(PrefsKeys.showRobotDetails, _showRobotDetails);
  }

  void _updateShowGrid(bool value) {
    setState(() {
      _showGrid = value;
    });
    _prefs.setBool(PrefsKeys.showGrid, _showGrid);
  }
}
