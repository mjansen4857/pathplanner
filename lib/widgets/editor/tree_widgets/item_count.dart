import 'package:flutter/material.dart';

class ItemCount extends StatelessWidget {
  final int count;

  const ItemCount({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(width: 2, color: colorScheme.surfaceVariant),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            color: colorScheme.surfaceVariant,
          ),
        ),
      ),
    );
  }
}
