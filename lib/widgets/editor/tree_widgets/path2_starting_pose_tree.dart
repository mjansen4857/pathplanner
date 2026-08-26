import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/path2/pathplanner_auto.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';
import 'package:pathplanner/widgets/editor/info_card.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

/// Edits the field-relative pose where a Path 2 auto begins.
class Path2StartingPoseTree extends StatelessWidget {
  final Path2Auto auto;
  final VoidCallback? onAutoChanged;
  final ChangeStack undoStack;
  final bool initiallyExpanded;

  const Path2StartingPoseTree({
    super.key,
    required this.auto,
    required this.undoStack,
    this.onAutoChanged,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final pose = auto.startingPose;

    return TreeCardNode(
      title: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Starting Pose'),
          InfoCard(
            value:
                'X: ${pose.x.toStringAsFixed(2)} M, Y: ${pose.y.toStringAsFixed(2)} M, ${pose.rotation.degrees.toStringAsFixed(2)}\u00b0',
          ),
        ],
      ),
      leading: const Icon(Icons.my_location_rounded),
      initiallyExpanded: initiallyExpanded,
      elevation: 1,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  key: const ValueKey('path2AutoStartingPoseX'),
                  initialValue: pose.x,
                  label: 'X Position (M)',
                  onSubmitted: (value) {
                    if (value != null && value.isFinite) {
                      _addChange(
                        Pose2d(
                          Translation2d(value, auto.startingPose.y),
                          auto.startingPose.rotation,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  key: const ValueKey('path2AutoStartingPoseY'),
                  initialValue: pose.y,
                  label: 'Y Position (M)',
                  onSubmitted: (value) {
                    if (value != null && value.isFinite) {
                      _addChange(
                        Pose2d(
                          Translation2d(auto.startingPose.x, value),
                          auto.startingPose.rotation,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  key: const ValueKey('path2AutoStartingPoseHeading'),
                  initialValue: pose.rotation.degrees,
                  label: 'Heading (Deg)',
                  arrowKeyIncrement: 1,
                  onSubmitted: (value) {
                    if (value != null && value.isFinite) {
                      _addChange(
                        Pose2d(
                          auto.startingPose.translation,
                          Rotation2d.fromDegrees(
                            MathUtil.inputModulus(value, -180, 180),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addChange(Pose2d newPose) {
    final oldValue = _StartingPoseState(
      auto.startingPose,
      auto.startingPoseInitialized,
    );

    undoStack.add(
      Change<_StartingPoseState>(
        oldValue,
        () {
          auto.setStartingPose(newPose);
          onAutoChanged?.call();
        },
        (previous) {
          auto.setStartingPose(previous.pose);
          auto.startingPoseInitialized = previous.initialized;
          onAutoChanged?.call();
        },
      ),
    );
  }
}

class _StartingPoseState {
  final Pose2d pose;
  final bool initialized;

  const _StartingPoseState(this.pose, this.initialized);
}
