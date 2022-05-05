import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/widgets/draggable_card.dart';

class PathInfoCard extends StatefulWidget {
  final RobotPath? path;
  final void Function(Offset, Size)? onDragged;
  final VoidCallback? onDragFinished;

  PathInfoCard(this.path, {this.onDragged, this.onDragFinished});

  @override
  _PathInfoCardState createState() => _PathInfoCardState();
}

class _PathInfoCardState extends State<PathInfoCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.path == null || widget.path!.generatedTrajectory == null)
      return Container();

    return DraggableCard(
      onDragged: widget.onDragged,
      onDragFinished: widget.onDragFinished,
      child: Center(
        child: Text(
            'Total Runtime: ${widget.path!.generatedTrajectory!.getRuntime().toStringAsFixed(2)}s'),
      ),
    );
  }
}
