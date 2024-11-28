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

    return Tooltip(
      message: 'Number of items',
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 18,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
