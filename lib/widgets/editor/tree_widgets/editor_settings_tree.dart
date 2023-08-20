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
  bool _displaySimPath = Defaults.displaySimPath;
  bool _snapToGuidelines = Defaults.snapToGuidelines;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((value) {
      setState(() {
        _prefs = value;
        _displaySimPath =
            _prefs.getBool(PrefsKeys.displaySimPath) ?? Defaults.displaySimPath;
        _snapToGuidelines = _prefs.getBool(PrefsKeys.snapToGuidelines) ??
            Defaults.snapToGuidelines;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      initiallyExpanded: widget.initiallyExpanded,
      title: const Text('Editor Settings'),
      children: [
        Row(
          children: [
            Checkbox(
              value: _displaySimPath,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _displaySimPath = val;
                    _prefs.setBool(PrefsKeys.displaySimPath, val);
                  });
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.only(
                bottom: 3.0,
                left: 4.0,
              ),
              child: Text(
                'Display Simulated Path',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: _snapToGuidelines,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _snapToGuidelines = val;
                    _prefs.setBool(PrefsKeys.snapToGuidelines, val);
                  });
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.only(
                bottom: 3.0,
                left: 4.0,
              ),
              child: Text(
                'Snap To Guidelines',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
