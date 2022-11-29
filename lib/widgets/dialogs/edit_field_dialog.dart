import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';

class EditFieldDialog extends StatefulWidget {
  final FieldImage fieldImage;

  const EditFieldDialog({required this.fieldImage, super.key});

  @override
  State<EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<EditFieldDialog> {
  late TextEditingController _nameController;
  late TextEditingController _ppmController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.fieldImage.name);
    _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nameController.text.length));

    _ppmController = TextEditingController(
        text: widget.fieldImage.pixelsPerMeter.toStringAsFixed(2));
    _ppmController.selection = TextSelection.fromPosition(
        TextPosition(offset: _ppmController.text.length));
  }

  @override
  Widget build(BuildContext context) {
    return KeyBoardShortcuts(
      keysToPress: {LogicalKeyboardKey.enter},
      onKeysPressed: () => confirm(context),
      child: AlertDialog(
        title: const Text('Edit Custom Field'),
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

  void confirm(BuildContext context) async {
    if (_nameController.text.isNotEmpty && _nameController.text.isNotEmpty) {
      Navigator.of(context).pop();

      String name = _nameController.text;
      double ppm = double.parse(_ppmController.text);

      Directory appDir = await getApplicationSupportDirectory();
      Directory imagesDir = Directory(join(appDir.path, 'custom_fields'));
      File imageFile = File(join(imagesDir.path,
          '${widget.fieldImage.name}_${widget.fieldImage.pixelsPerMeter.toStringAsFixed(2)}.${widget.fieldImage.extension}'));

      await imageFile.rename(join(imagesDir.path,
          '${name}_${ppm.toStringAsFixed(2)}.${widget.fieldImage.extension}'));

      widget.fieldImage.name = name;
      widget.fieldImage.pixelsPerMeter = ppm;
    }
  }
}
