import 'package:flutter/material.dart';
import 'package:pathplanner/commands/named_command.dart';

class NamedCommandWidget extends StatelessWidget {
  final NamedCommand command;
  final VoidCallback onUpdated;
  final VoidCallback onRemoved;

  const NamedCommandWidget({
    super.key,
    required this.command,
    required this.onUpdated,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            const Text('Named Command'),
            Expanded(child: Container()),
            IconButton(
              onPressed: onRemoved,
              visualDensity: const VisualDensity(
                  horizontal: VisualDensity.minimumDensity,
                  vertical: VisualDensity.minimumDensity),
              icon: Icon(Icons.close, color: colorScheme.error),
            ),
          ],
        )
      ],
    );
  }
}
