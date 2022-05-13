import 'package:flutter/material.dart';

import 'field_image.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final VoidCallback onGenerationEnabled;
  final ValueChanged<FieldImage> onFieldSelected;
  final List<FieldImage> fieldImages;
  final FieldImage selectedField;

  SettingsDialog(
      {required this.onSettingsChanged,
      required this.onGenerationEnabled,
      required this.onFieldSelected,
      required this.fieldImages,
      required this.selectedField,
      super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}
