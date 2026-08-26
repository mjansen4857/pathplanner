import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/services/project_event_registry.dart';

/// Manages named commands for the active project.
///
/// Path2 does not support linked waypoints, so this intentionally contains no
/// legacy linked-waypoint controls.
class ProjectEventsDialog extends StatefulWidget {
  final void Function(String oldName, String newName) onEventRenamed;
  final ValueChanged<String> onEventDeleted;

  const ProjectEventsDialog({
    super.key,
    required this.onEventRenamed,
    required this.onEventDeleted,
  });

  @override
  State<ProjectEventsDialog> createState() => _ProjectEventsDialogState();
}

class _ProjectEventsDialogState extends State<ProjectEventsDialog> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final events =
        ProjectEventRegistry.events.where((event) => event.isNotEmpty).toList()
          ..sort();

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      title: const Row(
        children: [Icon(Icons.abc), SizedBox(width: 8), Text('Manage Events')],
      ),
      content: SizedBox(
        width: 560,
        height: 320,
        child: events.isEmpty
            ? const Center(child: Text('No Events in Project'))
            : ListView(
                children: [
                  for (final eventName in events)
                    ListTile(
                      title: Text(eventName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rename event',
                            onPressed: () => _showRenameDialog(eventName),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: 'Remove event',
                            onPressed: () => _showDeleteDialog(eventName),
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

  Future<void> _showDeleteDialog(String eventName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: const Text('Remove Event'),
          content: Text(
            'Are you sure you want to remove the event "$eventName"? '
            'This cannot be undone.',
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
      widget.onEventDeleted(eventName);
      setState(() => ProjectEventRegistry.events.remove(eventName));
    }
  }

  Future<void> _showRenameDialog(String originalName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameEventDialog(originalName: originalName),
    );

    if (!mounted || newName == null || newName == originalName) {
      return;
    }
    if (newName.isEmpty) {
      _showMessage('Event names cannot be empty');
      return;
    }
    if (ProjectEventRegistry.events.contains(newName)) {
      _showMessage('An event with that name already exists');
      return;
    }

    widget.onEventRenamed(originalName, newName);
    setState(() {
      ProjectEventRegistry.events
        ..remove(originalName)
        ..add(newName);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RenameEventDialog extends StatefulWidget {
  final String originalName;

  const _RenameEventDialog({required this.originalName});

  @override
  State<_RenameEventDialog> createState() => _RenameEventDialogState();
}

class _RenameEventDialogState extends State<_RenameEventDialog> {
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
      title: const Text('Rename Event'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Event Name',
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
