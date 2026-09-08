import 'package:material_ui/material_ui.dart';
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

  static Size sizeFor(int count) => Size(220, 68 + count * 36);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          child: Material(
            color: colors.surfaceContainerHighest,
            shape: StadiumBorder(
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('editBranchTransition-${branch.id}'),
              onTap: onEditTransition,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: transitionBadge,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < branch.events.length; index++) ...[
          SizedBox(
            height: 30,
            child: EventChip(
              key: ValueKey('branchEventChip-${branch.id}-$index'),
              name: branch.events[index].name,
              status: status[index],
              onRemove: () => onRemove(index),
              trailing: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _EventPositionButton(
                  branchId: branch.id,
                  index: index,
                  position: branch.events[index].position,
                  onChanged: (value) => onPositionChanged(index, value),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        EventAddButton(
          names: branch.events.map((event) => event.name),
          onSelected: onAdd,
        ),
      ],
    );
  }
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
