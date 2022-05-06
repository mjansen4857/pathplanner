import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PathInfoCard extends StatefulWidget {
  final RobotPath? path;
  final GlobalKey stackKey;
  final SharedPreferences? prefs;

  PathInfoCard(this.path, this.stackKey, {this.prefs});

  @override
  _PathInfoCardState createState() => _PathInfoCardState();
}

class _PathInfoCardState extends State<PathInfoCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.path == null || widget.path!.generatedTrajectory == null)
      return Container();

    return DraggableCard(
      widget.stackKey,
      defaultPosition: CardPosition(top: 0, right: 0),
      prefsKey: 'pathCardPos',
      prefs: widget.prefs,
      child: Center(
        child: Text(
            'Total Runtime: ${widget.path!.generatedTrajectory!.getRuntime().toStringAsFixed(2)}s'),
      ),
    );
  }
}
