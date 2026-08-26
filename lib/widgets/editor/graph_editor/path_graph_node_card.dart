import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/graph_editor/visual_graph_editor.dart';
import 'package:pathplanner/widgets/number_text_field.dart';

typedef PathNodeEdit = void Function(
  String nodeId,
  void Function(path2.PathNode node) edit,
);

/// Compact graph representation of a waypoint.
///
/// Editable values deliberately live in [PathGraphNodeSettingsPanel] so cards
/// remain readable when a graph contains many nodes and branches.
class PathGraphNodeCard extends StatelessWidget {
  static const Size cardSize = Size(300, 142);

  static Size sizeFor(path2.Path path, path2.PathNode node) => cardSize;

  final path2.Path path;
  final path2.PathNode node;
  final bool selected;
  final ValueChanged<String> onDelete;
  final ValueChanged<String?> onHovered;
  final ValueChanged<String> onSelected;
  final List<double> estimatedRuntimeSeconds;

  const PathGraphNodeCard({
    super.key,
    required this.path,
    required this.node,
    required this.selected,
    required this.onDelete,
    required this.onHovered,
    required this.onSelected,
    this.estimatedRuntimeSeconds = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final waypoint = node.waypoint;
    final isRoot = path.rootNodes.any((root) => root.id == node.id);
    final isLeaf = path.isLeaf(node.id);
    final incoming = path.branches
        .where((branch) => branch.targetId == node.id)
        .length;
    final outgoing = path.branches
        .where((branch) => branch.sourceId == node.id)
        .length;

    return MouseRegion(
      onEnter: (_) => onHovered(node.id),
      onExit: (_) => onHovered(null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(node.id),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 14,
              bottom: 14,
              left: 0,
              right: 0,
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                elevation: selected ? 8 : 3,
                shape: RoundedRectangleBorder(
                  side: selected
                      ? BorderSide(color: colorScheme.primary, width: 2)
                      : BorderSide.none,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    GraphNodeDragHandle(
                      nodeId: node.id,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.only(left: 14, right: 4),
                        color: colorScheme.surfaceContainerHighest,
                        child: Row(
                          children: [
                            Icon(
                              waypoint is PoseWaypoint
                                  ? Icons.explore_outlined
                                  : Icons.location_on_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                waypoint is PoseWaypoint
                                    ? 'Pose waypoint'
                                    : 'Translation waypoint',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _CountBadge(
                              icon: Icons.call_received_rounded,
                              count: incoming,
                              tooltip: '$incoming incoming branches',
                            ),
                            _CountBadge(
                              icon: Icons.call_made_rounded,
                              count: outgoing,
                              tooltip: '$outgoing outgoing branches',
                            ),
                            IconButton(
                              key: ValueKey('deletePathNode-${node.id}'),
                              tooltip: path.nodes.length <= 1
                                  ? 'A path must contain at least one node'
                                  : 'Delete Waypoint',
                              onPressed: path.nodes.length <= 1
                                  ? null
                                  : () => onDelete(node.id),
                              color: colorScheme.error,
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (isRoot)
                                const _InfoBadge(
                                  icon: Icons.start_rounded,
                                  label: 'Start',
                                  color: Colors.green,
                                ),
                              if (isLeaf)
                                const _InfoBadge(
                                  icon: Icons.flag_outlined,
                                  label: 'End',
                                  color: Colors.red,
                                ),
                              if (isLeaf && estimatedRuntimeSeconds.isNotEmpty)
                                _InfoBadge(
                                  key: ValueKey('pathNodeRuntime-${node.id}'),
                                  icon: Icons.timer_outlined,
                                  label: _runtimeLabel(estimatedRuntimeSeconds),
                                  color: colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: cardSize.width / 2 - 14,
              child: GraphConnectorHandle(
                nodeId: node.id,
                side: GraphConnectorSide.top,
              ),
            ),
            Positioned(
              bottom: 0,
              left: cardSize.width / 2 - 14,
              child: GraphConnectorHandle(
                nodeId: node.id,
                side: GraphConnectorSide.bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _runtimeLabel(List<double> values) {
    final labels = values.map((value) => value.toStringAsFixed(2)).toSet();
    return '${labels.join(' / ')} s';
  }
}

/// Floating settings menu for the currently selected path node.
class PathGraphNodeSettingsPanel extends StatelessWidget {
  final path2.Path path;
  final path2.PathNode node;
  final PathNodeEdit onEdit;
  final VoidCallback onClose;

  const PathGraphNodeSettingsPanel({
    super.key,
    required this.path,
    required this.node,
    required this.onEdit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final waypoint = node.waypoint;
    final isLeaf = path.isLeaf(node.id);

    const radius = BorderRadius.all(Radius.circular(14));
    return DecoratedBox(
      key: ValueKey('pathNodeSettingsPanel-${node.id}'),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(110),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x4D1A1B22),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.only(left: 14, right: 4),
                    color: Colors.white.withAlpha(18),
                    child: Row(
                      children: [
                        Icon(
                          waypoint is PoseWaypoint
                              ? Icons.explore_outlined
                              : Icons.location_on_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            waypoint is PoseWaypoint
                                ? 'Pose waypoint settings'
                                : 'Translation waypoint settings',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('closePathNodeSettings'),
                          tooltip: 'Close Settings',
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      child: Column(
                        children: [
                          SwitchListTile(
                            key: ValueKey('pathNodePose-${node.id}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Pose waypoint'),
                            value: waypoint is PoseWaypoint,
                            onChanged: (isPose) => onEdit(node.id, (current) {
                              current.waypoint = current.waypoint.withRotation(
                                isPose ? const Rotation2d() : null,
                              );
                            }),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: NumberTextField(
                                  key: ValueKey('pathNodeX-${node.id}'),
                                  initialValue: waypoint.position.x,
                                  label: 'X Position (m)',
                                  onSubmitted: (value) {
                                    if (value != null && value.isFinite) {
                                      onEdit(
                                        node.id,
                                        (current) => current.waypoint.move(
                                          value,
                                          current.waypoint.position.y,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: NumberTextField(
                                  key: ValueKey('pathNodeY-${node.id}'),
                                  initialValue: waypoint.position.y,
                                  label: 'Y Position (m)',
                                  onSubmitted: (value) {
                                    if (value != null && value.isFinite) {
                                      onEdit(
                                        node.id,
                                        (current) => current.waypoint.move(
                                          current.waypoint.position.x,
                                          value,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (waypoint is PoseWaypoint) ...[
                            const SizedBox(height: 8),
                            NumberTextField(
                              key: ValueKey('pathNodeHeading-${node.id}'),
                              initialValue: waypoint.rotation.degrees,
                              label: 'Heading (deg)',
                              arrowKeyIncrement: 1,
                              onSubmitted: (value) {
                                if (value != null && value.isFinite) {
                                  onEdit(node.id, (current) {
                                    final currentWaypoint = current.waypoint;
                                    if (currentWaypoint is PoseWaypoint) {
                                      currentWaypoint.rotation =
                                          Rotation2d.fromDegrees(value);
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 8),
                          NumberTextField(
                            key: ValueKey('pathNodeMaxVelocity-${node.id}'),
                            initialValue: waypoint.maxVelocity,
                            label: 'Max Velocity (m/s)',
                            minValue: 0,
                            onSubmitted: (value) {
                              if (value != null &&
                                  value.isFinite &&
                                  value >= 0) {
                                onEdit(
                                  node.id,
                                  (current) =>
                                      current.waypoint.maxVelocity = value,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: NumberTextField(
                                  key: ValueKey(
                                    'pathNodeMaxAngularVelocity-${node.id}',
                                  ),
                                  initialValue: waypoint.maxAngularVelocity,
                                  label: 'Max Angular Vel. (deg/s)',
                                  minValue: 0,
                                  arrowKeyIncrement: 1,
                                  onSubmitted: (value) {
                                    if (value != null &&
                                        value.isFinite &&
                                        value >= 0) {
                                      onEdit(
                                        node.id,
                                        (current) =>
                                            current
                                                    .waypoint
                                                    .maxAngularVelocity =
                                                value,
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: NumberTextField(
                                  key: ValueKey(
                                    'pathNodeMaxAngularAcceleration-${node.id}',
                                  ),
                                  initialValue: waypoint.maxAngularAcceleration,
                                  label: 'Max Angular Acc. (deg/s²)',
                                  minValue: 0,
                                  arrowKeyIncrement: 1,
                                  onSubmitted: (value) {
                                    if (value != null &&
                                        value.isFinite &&
                                        value >= 0) {
                                      onEdit(
                                        node.id,
                                        (current) =>
                                            current
                                                    .waypoint
                                                    .maxAngularAcceleration =
                                                value,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (isLeaf) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: NumberTextField(
                                    key: ValueKey(
                                      'pathNodeDistanceTolerance-${node.id}',
                                    ),
                                    initialValue:
                                        node.endTolerance.distanceMeters,
                                    label: 'End Distance Tol. (m)',
                                    minValue: 0,
                                    onSubmitted: (value) {
                                      if (value != null &&
                                          value.isFinite &&
                                          value >= 0) {
                                        onEdit(
                                          node.id,
                                          (current) =>
                                              current
                                                      .endTolerance
                                                      .distanceMeters =
                                                  value,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                if (waypoint is PoseWaypoint) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: NumberTextField(
                                      key: ValueKey(
                                        'pathNodeAngleTolerance-${node.id}',
                                      ),
                                      initialValue:
                                          node.endTolerance.angleDegrees,
                                      label: 'End Angle Tol. (deg)',
                                      minValue: 0,
                                      arrowKeyIncrement: 1,
                                      onSubmitted: (value) {
                                        if (value != null &&
                                            value.isFinite &&
                                            value >= 0) {
                                          onEdit(
                                            node.id,
                                            (current) =>
                                                current
                                                        .endTolerance
                                                        .angleDegrees =
                                                    value,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String tooltip;

  const _CountBadge({
    required this.icon,
    required this.count,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 1),
            Text('$count', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
