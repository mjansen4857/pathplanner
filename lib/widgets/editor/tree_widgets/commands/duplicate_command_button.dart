import 'package:flutter/material.dart';

class DuplicateCommandButton extends StatelessWidget {
  final VoidCallback? onPressed;
  
  const DuplicateCommandButton({
    super.key,
    this.onPressed
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onPressed,
      icon: Icon(Icons.copy, color: colorScheme.primary)
    );
  }
}