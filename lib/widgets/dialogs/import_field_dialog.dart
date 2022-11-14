import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';

class ImportFieldDialog extends StatefulWidget {
  final Function(String name, double pixelsPerMeter, File imageFile) onImport;

  const ImportFieldDialog({required this.onImport, super.key});

  @override
  State<ImportFieldDialog> createState() => _ImportFieldDialogState();
}

class _ImportFieldDialogState extends State<ImportFieldDialog> {
  late TextEditingController _nameController;
  late TextEditingController _ppmController;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: 'Custom Field');
    _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nameController.text.length));

    _ppmController = TextEditingController(text: '100');
    _ppmController.selection = TextSelection.fromPosition(
        TextPosition(offset: _ppmController.text.length));
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return KeyBoardShortcuts(
      keysToPress: {LogicalKeyboardKey.enter},
      onKeysPressed: () => confirm(context),
      child: AlertDialog(
        title: const Text('Import Custom Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  height: 40,
                  width: 200,
                  child: TextField(
                    controller: _nameController,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(
                          RegExp('["*<>?|/:\\\\]')),
                    ],
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'Field Name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  width: 200,
                  child: TextField(
                    controller: _ppmController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'(^\d*\.?\d*)')),
                    ],
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'Pixels Per Meter',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Image: ',
                    ),
                    (_selectedFile == null)
                        ? Text(
                            'None Selected',
                            style: TextStyle(color: colorScheme.error),
                          )
                        : Text(
                            _selectedFile!.path
                                .split(Platform.pathSeparator)
                                .last,
                            style: TextStyle(color: colorScheme.primary),
                          ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () async {
                    const typeGroup =
                        XTypeGroup(label: 'images', extensions: ['jpg', 'png']);
                    final file = await openFile(
                        acceptedTypeGroups: [typeGroup],
                        initialDirectory: Directory.current.path);

                    if (file != null) {
                      setState(() {
                        _selectedFile = File(file.path);
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                  child: const Text('Choose File'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => confirm(context),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void confirm(BuildContext context) {
    if (_nameController.text.isNotEmpty &&
        _nameController.text.isNotEmpty &&
        _selectedFile != null) {
      Navigator.of(context).pop();
      widget.onImport.call(_nameController.text,
          double.parse(_ppmController.text), _selectedFile!);
    }
  }
}
