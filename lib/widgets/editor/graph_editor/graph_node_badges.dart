import 'package:material_ui/material_ui.dart';

class GraphCountBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String tooltip;

  const GraphCountBadge({
    super.key,
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

/// A tab with a flat lower edge attached to the top of the card.
class GraphCornerFlag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const GraphCornerFlag({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(maxWidth: 126),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withAlpha(35),
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        border: Border(
          top: BorderSide(color: color.withAlpha(100)),
          left: BorderSide(color: color.withAlpha(100)),
          right: BorderSide(color: color.withAlpha(100)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
