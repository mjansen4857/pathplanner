import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/util/units.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class StartingPoseTree extends StatelessWidget {
  final PathPlannerAuto auto;
  final VoidCallback? onAutoChanged;
  final ChangeStack undoStack;
  final bool initiallyExpanded;

  const StartingPoseTree({
    super.key,
    required this.auto,
    this.onAutoChanged,
    required this.undoStack,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Starting Pose'),
      initiallyExpanded: initiallyExpanded,
      elevation: 1.0,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  value: auto.startingPose?.position.x ?? 0,
                  label: 'X Position (M)',
                  enabled: auto.startingPose != null,
                  minValue: 0,
                  onSubmitted: (value) {
                    _addChange(() => auto.startingPose!.position =
                        Point(value, auto.startingPose!.position.y));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  value: auto.startingPose?.position.y ?? 0,
                  label: 'Y Position (M)',
                  enabled: auto.startingPose != null,
                  minValue: 0,
                  onSubmitted: (value) {
                    _addChange(() => auto.startingPose!.position =
                        Point(auto.startingPose!.position.x, value));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  value: auto.startingPose?.rotation ?? 0,
                  label: 'Rotation (Deg)',
                  enabled: auto.startingPose != null,
                  minValue: nonZeroAngle,
                  onSubmitted: (value) {
                    _addChange(
                        () => auto.startingPose!.rotation = adjustAngle(value));
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: auto.startingPose != null,
              onChanged: (value) {
                if (value ?? false) {
                  _addChange(() {
                    auto.startingPose = Pose2d(position: const Point(2, 2));
                  });
                } else {
                  _addChange(() {
                    auto.startingPose = null;
                  });
                }
              },
            ),
            const SizedBox(width: 4),
            const Text(
              'Preset Starting Pose',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ],
    );
  }

  void _addChange(VoidCallback execute) {
    undoStack.add(Change(
      auto.startingPose?.clone(),
      () {
        execute.call();
        onAutoChanged?.call();
      },
      (oldValue) {
        auto.startingPose = oldValue?.clone();
        onAutoChanged?.call();
      },
    ));
  }
}
