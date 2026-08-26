import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/services/project_condition_registry.dart';

/// Manages the condition names referenced by Path 2 path and auto branches.
class ProjectConditionsDialog extends StatefulWidget {
  final void Function(String oldName, String newName) onConditionRenamed;
  final ValueChanged<String> onConditionDeleted;

  const ProjectConditionsDialog({
    super.key,
    required this.onConditionRenamed,
    required this.onConditionDeleted,
  });

  @override
  State<ProjectConditionsDialog> createState() =>
      _ProjectConditionsDialogState();
}

class _ProjectConditionsDialogState extends State<ProjectConditionsDialog> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final conditions = ProjectConditionRegistry.conditions.toList()..sort();

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      title: const Row(
        children: [
          Icon(Icons.question_mark_rounded),
          SizedBox(width: 8),
          Text('Manage Conditions'),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 320,
        child: conditions.isEmpty
            ? const Center(child: Text('No Conditions in Project'))
            : ListView(
                children: [
                  for (final conditionName in conditions)
                    ListTile(
                      title: Text(conditionName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rename condition',
                            onPressed: () => _showRenameDialog(conditionName),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: 'Remove condition',
                            onPressed: () => _showDeleteDialog(conditionName),
                            icon: Icon(
                              Icons.delete_forever_rounded,
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _showDeleteDialog(String conditionName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: const Text('Remove Condition'),
          content: Text(
            'Remove the condition "$conditionName"? Branches that use it '
            'will remain in place with an unset condition.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      widget.onConditionDeleted(conditionName);
      setState(() => ProjectConditionRegistry.conditions.remove(conditionName));
    }
  }

  Future<void> _showRenameDialog(String originalName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameConditionDialog(originalName: originalName),
    );

    if (!mounted || newName == null || newName == originalName) {
      return;
    }
    if (newName.isEmpty) {
      _showMessage('Condition names cannot be empty');
      return;
    }
    if (ProjectConditionRegistry.conditions.contains(newName)) {
      _showMessage('A condition with that name already exists');
      return;
    }

    widget.onConditionRenamed(originalName, newName);
    setState(() {
      ProjectConditionRegistry.conditions
        ..remove(originalName)
        ..add(newName);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RenameConditionDialog extends StatefulWidget {
  final String originalName;

  const _RenameConditionDialog({required this.originalName});

  @override
  State<_RenameConditionDialog> createState() => _RenameConditionDialogState();
}

class _RenameConditionDialogState extends State<_RenameConditionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.originalName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      title: const Text('Rename Condition'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Condition Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
