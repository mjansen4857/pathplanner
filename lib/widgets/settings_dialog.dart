import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'field_image.dart';
import 'import_field_dialog.dart';
import 'keyboard_shortcuts.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final VoidCallback onGenerationEnabled;
  final ValueChanged<FieldImage> onFieldSelected;
  final List<FieldImage> fieldImages;
  final FieldImage selectedField;
  final SharedPreferences prefs;

  SettingsDialog(
      {required this.onSettingsChanged,
      required this.onGenerationEnabled,
      required this.onFieldSelected,
      required this.fieldImages,
      required this.selectedField,
      required this.prefs,
      super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _width;
  late double _length;
  late bool _holonomicMode;
  late bool _generateJSON;
  late bool _generateCSV;
  late FieldImage _selectedField;

  @override
  void initState() {
    super.initState();

    _width = widget.prefs.getDouble('robotWidth') ?? 0.75;
    _length = widget.prefs.getDouble('robotLength') ?? 1.0;
    _holonomicMode = widget.prefs.getBool('holonomicMode') ?? false;
    _generateJSON = widget.prefs.getBool('generateJSON') ?? false;
    _generateCSV = widget.prefs.getBool('generateCSV') ?? false;
    _selectedField = widget.selectedField;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Settings'),
      content: Container(
        width: 345,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Robot Size:'),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTextField(context, 'Width', (value) {
                  if (value != null) {
                    widget.prefs.setDouble('robotWidth', value);
                    setState(() {
                      _width = value;
                    });
                  }
                  widget.onSettingsChanged();
                }, _width.toStringAsFixed(2)),
                _buildTextField(context, 'Length', (value) {
                  if (value != null) {
                    widget.prefs.setDouble('robotLength', value);
                    setState(() {
                      _length = value;
                    });
                  }
                  widget.onSettingsChanged();
                }, _length.toStringAsFixed(2)),
              ],
            ),
            SizedBox(height: 18),
            _buildFieldImageDropdown(context),
            SizedBox(height: 24),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Additional Options:'),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text('Generate JSON'),
                      selected: _generateJSON,
                      onSelected: (value) {
                        widget.prefs.setBool('generateJSON', value);
                        setState(() {
                          _generateJSON = value;
                        });
                        widget.onSettingsChanged();
                        if (value) {
                          widget.onGenerationEnabled();
                        }
                      },
                    ),
                    FilterChip(
                      label: Text('Generate CSV'),
                      selected: _generateCSV,
                      onSelected: (value) {
                        widget.prefs.setBool('generateCSV', value);
                        setState(() {
                          _generateCSV = value;
                        });
                        widget.onSettingsChanged();
                        if (value) {
                          widget.onGenerationEnabled();
                        }
                      },
                    ),
                    FilterChip(
                      label: Text('Holonomic Mode'),
                      selected: _holonomicMode,
                      onSelected: (value) {
                        widget.prefs.setBool('holonomicMode', value);
                        setState(() {
                          _holonomicMode = value;
                        });
                        widget.onSettingsChanged();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, String label,
      ValueChanged? onSubmitted, String text) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        height: 40,
        width: 165,
        child: TextField(
          onSubmitted: (val) {
            if (onSubmitted != null) {
              var parsed = double.tryParse(val)!;
              onSubmitted.call(parsed);
            }
            _unfocus(context);
          },
          controller: TextEditingController(text: text)
            ..selection =
                TextSelection.fromPosition(TextPosition(offset: text.length)),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)')),
          ],
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldImageDropdown(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Field Image:'),
        SizedBox(height: 4),
        Container(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.outline),
              ),
              child: ExcludeFocus(
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButton<FieldImage?>(
                    dropdownColor: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    value: _selectedField,
                    isExpanded: true,
                    underline: Container(),
                    icon: Icon(Icons.arrow_drop_down),
                    style:
                        TextStyle(fontSize: 14, color: colorScheme.onSurface),
                    onChanged: (FieldImage? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedField = newValue;
                        });
                        widget.onFieldSelected(newValue);
                      } else {
                        _showFieldImportDialog(context);
                      }
                    },
                    items: [
                      ...widget.fieldImages.map<DropdownMenuItem<FieldImage>>(
                          (FieldImage value) {
                        return DropdownMenuItem<FieldImage>(
                          value: value,
                          child: Text(value.name),
                        );
                      }).toList(),
                      DropdownMenuItem<FieldImage?>(
                        value: null,
                        child: Text('Import Custom...'),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _unfocus(BuildContext context) {
    FocusScopeNode currentScope = FocusScope.of(context);
    if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
      FocusManager.instance.primaryFocus!.unfocus();
    }
  }

  void _showFieldImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ImportFieldDialog(onImport:
            (String name, double pixelsPerMeter, File imageFile) async {
          for (FieldImage image in widget.fieldImages) {
            if (image.name == name) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return KeyBoardShortcuts(
                    keysToPress: {LogicalKeyboardKey.enter},
                    onKeysPressed: () => Navigator.of(context).pop(),
                    child: AlertDialog(
                      title: Text('Failed to Import Field'),
                      content: Text(
                          'Field with the name "' + name + '" already exists.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              );
              return;
            }
          }

          Directory appDir = await getApplicationSupportDirectory();
          Directory imagesDir = Directory(join(appDir.path, 'custom_fields'));

          imagesDir.createSync(recursive: true);

          String imageExtension = imageFile.path.split('.').last;
          String importedPath = join(
              imagesDir.path,
              name +
                  '_' +
                  pixelsPerMeter.toStringAsFixed(2) +
                  '.' +
                  imageExtension);

          await imageFile.copy(importedPath);

          FieldImage newField = FieldImage.custom(File(importedPath));

          widget.onFieldSelected(newField);
        });
      },
    );
  }
}
