import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/widgets/editor/graph_editor/visual_graph_editor.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/widgets/editor/event_names_editor.dart';

/// Event assignments sit on the connection, with position edits in an anchored popup.
class PathBranchEventChips extends StatelessWidget {
  final path2.PathBranch branch;
  final Widget transitionBadge;
  final VoidCallback onEditTransition;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int index, double position) onPositionChanged;
  final Map<int, String> status;

  const PathBranchEventChips({
    super.key,
    required this.branch,
    required this.transitionBadge,
    required this.onEditTransition,
    required this.onAdd,
    required this.onRemove,
    required this.onPositionChanged,
    this.status = const {},
  });

  static Size sizeFor(int count) => BranchEventChips.sizeFor(count);

  @override
  Widget build(BuildContext context) => BranchEventChips(
    branchId: branch.id,
    names: branch.events.map((event) => event.name).toList(),
    transitionBadge: transitionBadge,
    onEditTransition: onEditTransition,
    onAdd: onAdd,
    onRemove: onRemove,
    status: status,
    trailingBuilder: (index) => Padding(
      padding: const EdgeInsets.only(left: 8),
      child: _EventPositionButton(
        branchId: branch.id,
        index: index,
        position: branch.events[index].position,
        onChanged: (value) => onPositionChanged(index, value),
      ),
    ),
  );
}

/// Shared connection events, with optional extra controls for path positions.
class BranchEventChips extends StatelessWidget {
  final String branchId;
  final List<String> names;
  final Widget transitionBadge;
  final VoidCallback onEditTransition;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;
  final Map<int, String> status;
  final Widget Function(int index)? trailingBuilder;

  const BranchEventChips({
    super.key,
    required this.branchId,
    required this.names,
    required this.transitionBadge,
    required this.onEditTransition,
    required this.onAdd,
    required this.onRemove,
    this.status = const {},
    this.trailingBuilder,
  });

  static Size sizeFor(int count) =>
      Size(220, 28 + (count > 0 ? 8 + count * 36 : 0));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BranchTransitionBubble(
          branchId: branchId,
          names: names,
          onAdd: onAdd,
          onEditTransition: onEditTransition,
          transitionBadge: transitionBadge,
        ),
        if (names.isNotEmpty) const SizedBox(height: 8),
        for (var index = 0; index < names.length; index++) ...[
          SizedBox(
            height: 30,
            child: EventChip(
              key: ValueKey('branchEventChip-$branchId-$index'),
              name: names[index],
              status: status[index],
              onRemove: () => onRemove(index),
              trailing: trailingBuilder?.call(index),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// The transition stays fixed while its add control separates like a droplet.
class _BranchTransitionBubble extends StatefulWidget {
  final String branchId;
  final List<String> names;
  final ValueChanged<String> onAdd;
  final VoidCallback onEditTransition;
  final Widget transitionBadge;

  const _BranchTransitionBubble({
    required this.branchId,
    required this.names,
    required this.onAdd,
    required this.onEditTransition,
    required this.transitionBadge,
  });

  @override
  State<_BranchTransitionBubble> createState() =>
      _BranchTransitionBubbleState();
}

class _BranchTransitionBubbleState extends State<_BranchTransitionBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
  );
  bool _near = false;
  bool _reduceMotion = false;
  double _target = 0;

  bool get _visible => _near || _hovered || _focused || _menuOpen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _near = GraphBranchProximity.of(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _retarget();
  }

  void _retarget() {
    final target = _visible ? 1.0 : 0.0;
    if (_reduceMotion) {
      _target = target;
      _motion.value = target;
    } else if (target != _target) {
      _target = target;
      // Carry velocity through reversals, so a quick mouse exit never resets
      // the easing curve or snaps the stretching surface to a new pose.
      _motion.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 170, damping: 26),
          _motion.value,
          target,
          _motion.velocity,
          tolerance: const Tolerance(distance: 0.001, velocity: 0.001),
        ),
      );
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _retarget();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  bool _hovered = false;
  bool _focused = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = _visible;
    return MouseRegion(
      onEnter: (_) => _update(() => _hovered = true),
      onExit: (_) => _update(() => _hovered = false),
      child: Focus(
        onFocusChange: (focused) => _update(() {
          // Mouse activation restores focus after the menu closes; only
          // keyboard focus should keep a distant branch's button visible.
          _focused =
              focused &&
              HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty;
        }),
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) _update(() => _focused = true);
          return KeyEventResult.ignored;
        },
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, child) {
            final progress = _motion.isAnimating
                ? _motion.value.clamp(0.0, 1.0)
                : _target;
            final droplet = _DropletGeometry(progress);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 32),
                Flexible(
                  child: CustomPaint(
                    painter: _LiquidBubblePainter(
                      progress: progress,
                      fill: colors.surfaceContainerHighest,
                      outline: colors.outlineVariant,
                    ),
                    child: SizedBox(
                      height: 28,
                      child: Material(
                        color: Colors.transparent,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey(
                            'editBranchTransition-${widget.branchId}',
                          ),
                          onTap: widget.onEditTransition,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: widget.transitionBadge,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: ExcludeFocus(
                      excluding: !visible,
                      child: ExcludeSemantics(
                        excluding: !visible,
                        child: Transform.translate(
                          offset: Offset(droplet.center - 18, 0),
                          child: Transform.scale(
                            scale:
                                0.82 + 0.18 * _smoothStep(0.25, 0.9, progress),
                            child: Opacity(
                              key: ValueKey(
                                'branchAddEventVisibility-${widget.branchId}',
                              ),
                              opacity: _smoothStep(0.28, 0.88, progress),
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: IconButtonTheme(
                                  data: IconButtonThemeData(
                                    style: IconButton.styleFrom(
                                      foregroundColor: colors.onSurface,
                                    ),
                                  ),
                                  child: Tooltip(
                                    message: 'Add event',
                                    child: EventAddButton(
                                      names: widget.names,
                                      onSelected: widget.onAdd,
                                      compact: true,
                                      onMenuOpenChanged: (open) =>
                                          _update(() => _menuOpen = open),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LiquidBubblePainter extends CustomPainter {
  final double progress;
  final Color fill;
  final Color outline;

  const _LiquidBubblePainter({
    required this.progress,
    required this.fill,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _surface(size);
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  Path _surface(Size size) {
    final capsule = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    if (progress <= 0) return Path()..addRRect(capsule);
    if (progress >= 1) {
      return Path()
        ..addRRect(capsule)
        ..addOval(
          Rect.fromCircle(center: Offset(size.width + 18, 14), radius: 14),
        );
    }
    final droplet = _DropletGeometry(progress);
    // A smooth union of distance fields gives the entire outline one surface.
    // There is no separately drawn bridge or frame at which a neck is deleted:
    // its thickness tends to zero and the surface separates by itself.
    double field(double x, double y) {
      final capX = x.clamp(14.0, math.max(14.0, size.width - 14));
      final capsuleDistance = math.sqrt((x - capX) * (x - capX) + y * y) - 14;
      final dx = (x - size.width - droplet.center) / droplet.radiusX;
      final dy = y / droplet.radiusY;
      final bubbleDistance =
          (math.sqrt(dx * dx + dy * dy) - 1) *
          math.min(droplet.radiusX, droplet.radiusY);
      final h =
          math.max(
            droplet.blend - (capsuleDistance - bubbleDistance).abs(),
            0,
          ) /
          droplet.blend;
      return math.min(capsuleDistance, bubbleDistance) -
          h * h * droplet.blend * 0.25;
    }

    final shape = Path();
    // Keep the unchanged left side exact; sample only the deforming right cap.
    final startX = math.max(14.0, size.width - 30);
    final endX = size.width + droplet.center + droplet.radiusX + droplet.blend;
    final upper = <Offset>[];
    var attachedToChip = true;
    void closeLobe() {
      if (upper.isEmpty) return;
      if (attachedToChip) {
        shape.moveTo(startX, 0);
      } else {
        shape.moveTo(upper.first.dx, 14);
      }
      for (final point in upper) {
        shape.lineTo(point.dx, 14 - point.dy);
      }
      for (final point in upper.reversed) {
        shape.lineTo(point.dx, 14 + point.dy);
      }
      if (attachedToChip) {
        shape.lineTo(14, 28);
        shape.arcToPoint(
          const Offset(14, 0),
          radius: const Radius.circular(14),
        );
        shape.lineTo(startX, 0);
      }
      shape.close();
      upper.clear();
      attachedToChip = false;
    }

    // Subpixel contours stay smooth at editor zoom levels. Bisection finds the
    // actual isosurface instead of approximating it with overlapping circles.
    const step = 0.2;
    double boundaryBetween(double left, double right) {
      final leftInside = field(left, 0) <= 0;
      for (var i = 0; i < 18; i++) {
        final middle = (left + right) / 2;
        if ((field(middle, 0) <= 0) == leftInside) {
          left = middle;
        } else {
          right = middle;
        }
      }
      return (left + right) / 2;
    }

    for (var x = startX; x <= endX; x += step) {
      if (field(x, 0) > 0) {
        if (upper.isNotEmpty) {
          // End at the actual zero crossing. Closing at the last sample
          // draws a vertical chord that visibly chops off the rounded tip.
          upper.add(Offset(boundaryBetween(x - step, x), 0));
          closeLobe();
        }
        continue;
      }
      if (upper.isEmpty && !attachedToChip) {
        upper.add(Offset(boundaryBetween(x - step, x), 0));
      }
      var low = 0.0;
      var high = 24.0;
      for (var i = 0; i < 12; i++) {
        final mid = (low + high) / 2;
        if (field(x, mid) <= 0) {
          low = mid;
        } else {
          high = mid;
        }
      }
      upper.add(Offset(x, (low + high) / 2));
    }
    closeLobe();
    // The fluid union always contains the original chip. Preserve its exact
    // circular cap rather than letting contour sampling trim its silhouette.
    return Path.combine(PathOperation.union, Path()..addRRect(capsule), shape);
  }

  @override
  bool shouldRepaint(_LiquidBubblePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      fill != oldDelegate.fill ||
      outline != oldDelegate.outline;
}

double _smoothStep(double start, double end, double value) {
  final t = ((value - start) / (end - start)).clamp(0.0, 1.0);
  return t * t * t * (t * (t * 6 - 15) + 10);
}

/// One geometry model drives both the moving surface and its icon.
class _DropletGeometry {
  final double center;
  final double radiusX;
  final double radiusY;
  final double blend;

  _DropletGeometry(double progress)
    : center = -14 + 32 * progress,
      // Stretch along the direction of travel, then recover a round button.
      // The paired axes keep the droplet's area nearly constant as it stretches.
      radiusX =
          (10 + 4 * _smoothStep(0, 0.65, progress)) *
          (1 + 0.18 * math.sin(math.pi * progress)),
      radiusY =
          (10 + 4 * _smoothStep(0, 0.65, progress)) /
          (1 + 0.18 * math.sin(math.pi * progress)),
      blend =
          0.01 +
          15 *
              _smoothStep(0, 0.28, progress) *
              (1 - _smoothStep(0.55, 1, progress));
}

class _EventPositionButton extends StatefulWidget {
  final String branchId;
  final int index;
  final double position;
  final ValueChanged<double> onChanged;

  const _EventPositionButton({
    required this.branchId,
    required this.index,
    required this.position,
    required this.onChanged,
  });

  @override
  State<_EventPositionButton> createState() => _EventPositionButtonState();
}

class _EventPositionButtonState extends State<_EventPositionButton> {
  double? _draft;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = _draft ?? widget.position;
    return MenuAnchor(
      useRootOverlay: true,
      consumeOutsideTap: true,
      alignmentOffset: const Offset(36, 0),
      style: const MenuStyle(
        alignment: Alignment.topRight,
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      onClose: () => setState(() => _draft = null),
      menuChildren: [
        SizedBox(
          width: 260,
          height: 48,
          child: Slider(
            key: ValueKey(
              'branchEventPosition-${widget.branchId}-${widget.index}',
            ),
            value: value,
            label: '${(value * 100).round()}%',
            onChanged: (value) => setState(() => _draft = value),
            onChangeEnd: (value) {
              widget.onChanged(value);
              setState(() => _draft = null);
            },
          ),
        ),
      ],
      builder: (context, controller, child) => InkWell(
        key: ValueKey('branchEventPercent-${widget.branchId}-${widget.index}'),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(28),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: 11,
              color: colors.primary,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
