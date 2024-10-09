import 'package:flutter/material.dart';

class AddCommandButton extends StatelessWidget {
  final ValueChanged<String> onTypeChosen;
  final bool allowPathCommand;
  final bool allowWaitCommand;

  const AddCommandButton({
    super.key,
    required this.onTypeChosen,
    required this.allowPathCommand,
    this.allowWaitCommand = true,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton(
      tooltip: 'Add Command',
      elevation: 12.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      icon: Icon(Icons.add, color: colorScheme.primary),
      itemBuilder: (context) => _getMenuEntries(),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        onTypeChosen.call(value);
      },
    );
  }

  List<PopupMenuEntry<String>> _getMenuEntries() {
    return [
      if (allowPathCommand)
        const PopupMenuItem(
          value: 'path',
          child: Text('Follow Path'),
        ),
      const PopupMenuItem(
        value: 'named',
        child: Text('Named Command'),
      ),
      if (allowWaitCommand)
        const PopupMenuItem(
          value: 'wait',
          child: Text('Wait Command'),
        ),
      const PopupMenuItem(
        value: 'sequential',
        child: Text('Sequential Command Group'),
      ),
      const PopupMenuItem(
        value: 'parallel',
        child: Text('Parallel Command Group'),
      ),
      const PopupMenuItem(
        value: 'deadline',
        child: Text('Parallel Deadline Group'),
      ),
      const PopupMenuItem(
        value: 'race',
        child: Text('Parallel Race Group'),
      ),
    ];
  }
}
