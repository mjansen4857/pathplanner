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
      icon: const Icon(Icons.settings),
      elevation: 1.0,
      children: [
        _buildCheckboxRow(
          'Snap To Guidelines',
          _snapToGuidelines,
          (val) => _updateSetting(PrefsKeys.snapToGuidelines, val),
          'Enable or disable snapping to guidelines.',
        ),
        _buildCheckboxRow(
          'Hide Other Paths on Hover',
          _hidePathsOnHover,
          (val) => _updateSetting(PrefsKeys.hidePathsOnHover, val),
          'Hide other paths when hovering over a specific path.',
        ),
        _buildCheckboxRow(
          'Show Robot Details',
          _showRobotDetails,
          (val) => _updateSetting(PrefsKeys.showRobotDetails, val),
          'Display additional details about the robots current rotation and position.',
        ),
        _buildCheckboxRow(
          'Show Grid',
          _showGrid,
          (val) => _updateSetting(PrefsKeys.showGrid, val),
          'Toggle the visibility of the grid on the field. Each cell is 0.5M x 0.5M.',
        ),
      ],
    );
  }

  Widget _buildCheckboxRow(
      String label, bool value, Function(bool?) onChanged, String tooltip) {
    return Row(
      children: [
        Tooltip(
          message: tooltip,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
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

  void _updateSetting(String key, bool? value) {
    if (value != null) {
      setState(() {
        switch (key) {
          case PrefsKeys.snapToGuidelines:
            _snapToGuidelines = value;
            break;
          case PrefsKeys.hidePathsOnHover:
            _hidePathsOnHover = value;
            break;
          case PrefsKeys.showRobotDetails:
            _showRobotDetails = value;
            break;
          case PrefsKeys.showGrid:
            _showGrid = value;
            break;
        }
        _prefs.setBool(key, value);
      });
    }
  }
}
