import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts/keyboard_shortcuts.dart';

class ImportFieldDialog extends StatefulWidget {
  final Function(String name, double pixelsPerMeter, File imageFile) onImport;

  ImportFieldDialog(this.onImport, {Key? key}) : super(key: key);

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
    return KeyBoardShortcuts(
      keysToPress: {LogicalKeyboardKey.enter},
      onKeysPressed: () => confirm(context),
      child: AlertDialog(
        title: Text('Import Custom Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  height: 40,
                  width: 200,
                  child: TextField(
                    controller: _nameController,
                    cursorColor: Colors.white,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(
                          RegExp("[\"*<>?\|/:\\\\]")),
                    ],
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'Field Name',
                      filled: true,
                      border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  height: 40,
                  width: 200,
                  child: TextField(
                    controller: _ppmController,
                    cursorColor: Colors.white,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'(^\d*\.?\d*)')),
                    ],
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'Pixels Per Meter',
                      filled: true,
                      border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Image: ',
                    ),
                    (_selectedFile == null)
                        ? Text(
                            'None Selected',
                            style: TextStyle(color: Colors.red),
                          )
                        : Text(
                            _selectedFile!.path
                                .split(Platform.pathSeparator)
                                .last,
                            style: TextStyle(color: Colors.grey),
                          ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () async {
                    final typeGroup =
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
                  child: Text('Choose File'),
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
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.indigoAccent),
            ),
          ),
          TextButton(
            onPressed: () => confirm(context),
            child: Text(
              'Confirm',
              style: TextStyle(color: Colors.indigoAccent),
            ),
          ),
        ],
      ),
    );
  }

  void confirm(BuildContext context) {
    if (_nameController.text.length > 0 &&
        _nameController.text.length > 0 &&
        _selectedFile != null) {
      Navigator.of(context).pop();
      widget.onImport.call(_nameController.text,
          double.parse(_ppmController.text), _selectedFile!);
    }
  }
}
