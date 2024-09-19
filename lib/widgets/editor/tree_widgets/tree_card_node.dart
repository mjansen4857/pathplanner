import 'package:flutter/material.dart';

class TreeCardNode extends StatelessWidget {
  final Widget title;
  final Widget? leading;
  final double elevation;
  final List<Widget> children;
  final VoidCallback? onHoverStart;
  final VoidCallback? onHoverEnd;
  final double indent;
  final bool initiallyExpanded;
  final ExpansionTileController? controller;
  final ValueChanged<bool?>? onExpansionChanged;
  final Widget? trailing;

  const TreeCardNode({
    super.key,
    required this.title,
    this.leading,
    this.elevation = 2,
    required this.children,
    this.onHoverStart,
    this.onHoverEnd,
    this.indent = 16,
    this.initiallyExpanded = false,
    this.controller,
    this.onExpansionChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: elevation,
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        child: MouseRegion(
          onEnter: (event) => onHoverStart?.call(),
          onExit: (event) => onHoverEnd?.call(),
          child: ExpansionTile(
            title: Row(
              children: [
                if (leading != null) leading!,
                if (leading != null) const SizedBox(width: 8),
                Expanded(child: title),
              ],
            ),
            trailing: trailing,
            controller: controller,
            maintainState: false,
            onExpansionChanged: onExpansionChanged,
            initiallyExpanded: initiallyExpanded,
            controlAffinity: ListTileControlAffinity.leading,
            childrenPadding: EdgeInsets.fromLTRB(indent, 8, 8, 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}
