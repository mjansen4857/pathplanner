import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/services/project_event_registry.dart';

const eventLabelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);

/// Compact, removable event assignment used on cards and graph connections.
class EventChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;
  final Widget? trailing;
  final String? status;

  const EventChip({
    super.key,
    required this.name,
    required this.onRemove,
    this.trailing,
    this.status,
  });

  static double widthFor(String name, TextScaler textScaler) {
    final text = TextPainter(
      text: TextSpan(text: name, style: eventLabelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return math.min(272, text.width.ceilToDouble() + 42);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Color.lerp(colors.surface, colors.primary, 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.primary.withAlpha(65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 30,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 10),
            if (status != null) ...[
              Tooltip(
                message: status!,
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 13,
                  color: colors.error,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                name,
                style: eventLabelStyle.copyWith(color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing!,
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 13),
              style: IconButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
                minimumSize: const Size(28, 30),
                maximumSize: const Size(28, 30),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picker is anchored to its add button, so the graph remains in view.
class EventAddButton extends StatefulWidget {
  final Iterable<String> names;
  final ValueChanged<String> onSelected;
  final bool compact;
  final ValueChanged<bool>? onMenuOpenChanged;

  const EventAddButton({
    super.key,
    this.names = const [],
    required this.onSelected,
    this.compact = false,
    this.onMenuOpenChanged,
  });
  @override
  State<EventAddButton> createState() => _EventAddButtonState();
}

class _EventAddButtonState extends State<EventAddButton> {
  final MenuController _menu = MenuController();
  int _opening = 0;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    onOpen: () => widget.onMenuOpenChanged?.call(true),
    onClose: () => widget.onMenuOpenChanged?.call(false),
    useRootOverlay: true,
    consumeOutsideTap: true,
    alignmentOffset: const Offset(0, 5),
    style: const MenuStyle(padding: WidgetStatePropertyAll(EdgeInsets.all(6))),
    menuChildren: [
      _EventNameMenu(
        key: ValueKey(_opening),
        names: {...ProjectEventRegistry.events, ...widget.names},
        onSelected: (name) {
          _menu.close();
          widget.onSelected(name);
        },
      ),
    ],
    builder: (context, controller, child) {
      void toggle() {
        if (controller.isOpen) {
          controller.close();
        } else {
          setState(() => _opening++);
          controller.open();
        }
      }

      if (widget.compact) {
        return IconButton(
          onPressed: toggle,
          icon: const Icon(Icons.add_rounded, size: 17),
          style: IconButton.styleFrom(
            minimumSize: const Size(28, 28),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: toggle,
          icon: const Icon(Icons.add_rounded, size: 14),
          label: const Text('Add event'),
          style: OutlinedButton.styleFrom(
            textStyle: eventLabelStyle,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 32),
            visualDensity: VisualDensity.standard,
            alignment: Alignment.center,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Color.lerp(
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primary,
              0.05,
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary.withAlpha(75),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    },
  );
}

class _EventNameMenu extends StatefulWidget {
  final Set<String> names;
  final ValueChanged<String> onSelected;
  const _EventNameMenu({
    super.key,
    required this.names,
    required this.onSelected,
  });
  @override
  State<_EventNameMenu> createState() => _EventNameMenuState();
}

class _EventNameMenuState extends State<_EventNameMenu> {
  final TextEditingController _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final matches =
        widget.names
            .where((name) => name.toLowerCase().contains(query.toLowerCase()))
            .toList()
          ..sort();
    return SizedBox(
      width: 256,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: TextField(
              controller: _search,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Find or create an event',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (matches.isNotEmpty) {
                  widget.onSelected(matches.first);
                } else if (query.isNotEmpty) {
                  widget.onSelected(query);
                }
              },
            ),
          ),
          if (matches.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final name in matches)
                      MenuItemButton(
                        onPressed: () => widget.onSelected(name),
                        leadingIcon: const Icon(Icons.bolt_rounded, size: 16),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (query.isNotEmpty && !widget.names.contains(query))
            MenuItemButton(
              onPressed: () => widget.onSelected(query),
              leadingIcon: const Icon(Icons.add_rounded, size: 16),
              child: Text(
                'Create “$query”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Type a name to create an event',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class WaypointEventsSection extends StatelessWidget {
  final List<String> names;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;
  const WaypointEventsSection({
    super.key,
    required this.names,
    required this.onAdd,
    required this.onRemove,
  });

  static double heightFor(List<String> names, TextScaler scaler) {
    if (names.isEmpty) return 38;
    var rows = 1;
    var width = 0.0;
    for (final name in names) {
      final chipWidth = EventChip.widthFor(name, scaler);
      if (width > 0 && width + 6 + chipWidth > 272) {
        rows++;
        width = 0;
      }
      width += (width > 0 ? 6 : 0) + chipWidth;
    }
    return 38 + rows * 30 + (rows - 1) * 6 + 10;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withAlpha(100)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(12, 4, 12, names.isEmpty ? 4 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 30,
            child: Row(
              children: [
                Text(
                  'Events',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                EventAddButton(names: names, onSelected: onAdd, compact: true),
              ],
            ),
          ),
          if (names.isNotEmpty) const SizedBox(height: 4),
          if (names.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var index = 0; index < names.length; index++)
                  SizedBox(
                    width: EventChip.widthFor(
                      names[index],
                      MediaQuery.textScalerOf(context),
                    ),
                    child: EventChip(
                      name: names[index],
                      onRemove: () => onRemove(index),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
