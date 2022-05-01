import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts/keyboard_shortcuts.dart';

class ImportFieldDialog extends StatefulWidget {
  final ValueChanged<FieldImage> onImport;

  ImportFieldDialog(this.onImport, {Key? key}) : super(key: key);

  @override
  State<ImportFieldDialog> createState() => _ImportFieldDialogState();
}

class _ImportFieldDialogState extends State<ImportFieldDialog> {
  bool _confirmEnabled = false;

  @override
  Widget build(BuildContext context) {
    return KeyBoardShortcuts(
      keysToPress: {LogicalKeyboardKey.enter},
      onKeysPressed: () => confirm(context),
      child: AlertDialog(
        title: Text('Import Custom Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.indigoAccent),
            ),
          ),
          TextButton(
            onPressed: _confirmEnabled ? () => confirm(context) : null,
            child: Text(
              'Confirm',
              style: TextStyle(
                  color: _confirmEnabled ? Colors.indigoAccent : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void confirm(BuildContext context) {
    if (_confirmEnabled) {
      Navigator.of(context).pop();
    }
  }
}
