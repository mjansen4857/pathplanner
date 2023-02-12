import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pathplanner/widgets/dialogs/edit_field_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../field_image.dart';
import 'import_field_dialog.dart';
import '../keyboard_shortcuts.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final VoidCallback onGenerationEnabled;
  final ValueChanged<FieldImage> onFieldSelected;
  final List<FieldImage> fieldImages;
  final FieldImage selectedField;
  final SharedPreferences prefs;
  final ValueChanged<Color> onTeamColorChanged;

  const SettingsDialog(
      {required this.onSettingsChanged,
      required this.onGenerationEnabled,
      required this.onFieldSelected,
      required this.fieldImages,
      required this.selectedField,
      required this.prefs,
      required this.onTeamColorChanged,
      super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _width;
  late double _length;
  late bool _holonomicMode;
  late bool _focusedSelection;
  late bool _generateJSON;
  late bool _generateCSV;
  late bool _pplibClient;
  late FieldImage _selectedField;
  late Color _teamColor;
  late String _pplibClientHost;
  late int _pplibClientPort;

  @override
  void initState() {
    super.initState();

    _width = widget.prefs.getDouble('robotWidth') ?? 0.75;
    _length = widget.prefs.getDouble('robotLength') ?? 1.0;
    _holonomicMode = widget.prefs.getBool('holonomicMode') ?? false;
    _focusedSelection = widget.prefs.getBool('focusedSelection') ?? false;
    _generateJSON = widget.prefs.getBool('generateJSON') ?? false;
    _generateCSV = widget.prefs.getBool('generateCSV') ?? false;
    _pplibClient = widget.prefs.getBool('pplibClient') ?? false;
    _selectedField = widget.selectedField;
    _teamColor = Color(widget.prefs.getInt('teamColor') ?? Colors.indigo.value);
    _pplibClientHost =
        widget.prefs.getString('pplibClientHost') ?? '10.30.15.2';
    _pplibClientPort = widget.prefs.getInt('pplibClientPort') ?? 5811;
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 345,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Robot Size:'),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTextField(
                  context,
                  'Width',
                  (value) {
                    double? val = double.tryParse(value);
                    if (val != null) {
                      widget.prefs.setDouble('robotWidth', val);
                      setState(() {
                        _width = val;
                      });
                    }
                    widget.onSettingsChanged();
                  },
                  _width.toStringAsFixed(2),
                  FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)')),
                ),
                _buildTextField(
                  context,
                  'Length',
                  (value) {
                    double? val = double.tryParse(value);
                    if (val != null) {
                      widget.prefs.setDouble('robotLength', val);
                      setState(() {
                        _length = val;
                      });
                    }
                    widget.onSettingsChanged();
                  },
                  _length.toStringAsFixed(2),
                  FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldImageDropdown(context),
                _buildTeamColorPicker(context),
              ],
            ),
            const SizedBox(height: 12),
            if (_pplibClient)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PPLib Client:'),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTextField(
                        context,
                        'Host',
                        (value) {
                          widget.prefs.setString('pplibClientHost', value);
                          setState(() {
                            _pplibClientHost = value;
                          });
                          widget.onSettingsChanged();
                        },
                        _pplibClientHost,
                        null,
                      ),
                      _buildTextField(
                        context,
                        'Port',
                        (value) {
                          int? val = int.tryParse(value);
                          if (val != null) {
                            widget.prefs.setInt('pplibClientPort', val);
                            setState(() {
                              _pplibClientPort = val;
                            });
                          }
                          widget.onSettingsChanged();
                        },
                        _pplibClientPort.toString(),
                        FilteringTextInputFormatter.allow(RegExp(r'(^\d*)')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Additional Options:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Generate JSON'),
                      labelStyle: TextStyle(
                          color: _generateJSON
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface),
                      selected: _generateJSON,
                      backgroundColor: colorScheme.surface,
                      selectedColor: colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: _generateJSON
                                  ? colorScheme.primaryContainer
                                  : colorScheme.outline,
                              width: 1)),
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
                      label: const Text('Generate CSV'),
                      labelStyle: TextStyle(
                          color: _generateCSV
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface),
                      selected: _generateCSV,
                      backgroundColor: colorScheme.surface,
                      selectedColor: colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: _generateCSV
                                  ? colorScheme.primaryContainer
                                  : colorScheme.outline,
                              width: 1)),
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
                      label: const Text('Holonomic Mode'),
                      labelStyle: TextStyle(
                          color: _holonomicMode
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface),
                      selected: _holonomicMode,
                      backgroundColor: colorScheme.surface,
                      selectedColor: colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: _holonomicMode
                                  ? colorScheme.primaryContainer
                                  : colorScheme.outline,
                              width: 1)),
                      onSelected: (value) {
                        widget.prefs.setBool('holonomicMode', value);
                        setState(() {
                          _holonomicMode = value;
                        });
                        widget.onSettingsChanged();
                      },
                    ),
                    FilterChip(
                      label: const Text('Focused Selection'),
                      labelStyle: TextStyle(
                          color: _focusedSelection
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface),
                      selected: _focusedSelection,
                      backgroundColor: colorScheme.surface,
                      selectedColor: colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: _focusedSelection
                                  ? colorScheme.primaryContainer
                                  : colorScheme.outline,
                              width: 1)),
                      onSelected: (value) {
                        widget.prefs.setBool('focusedSelection', value);
                        setState(() {
                          _focusedSelection = value;
                        });
                        widget.onSettingsChanged();
                      },
                    ),
                    FilterChip(
                      label: const Text('PPLib Client'),
                      labelStyle: TextStyle(
                          color: _pplibClient
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface),
                      selected: _pplibClient,
                      backgroundColor: colorScheme.surface,
                      selectedColor: colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: _pplibClient
                                  ? colorScheme.primaryContainer
                                  : colorScheme.outline,
                              width: 1)),
                      onSelected: (value) async {
                        bool enable = false;
                        if (value) {
                          await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('PPLib Client'),
                                content: SizedBox(
                                  width: 300,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                          'If enabled, this setting will allow PathPlanner to connect to a PathPlannerLib server running in your robot code. This will display a path following visualization in a new editor tab and automatically update path files on the robot to match local changes. Are you sure you want to enable this functionality?'),
                                      SizedBox(height: 16),
                                      Text(
                                          'Unfortunately, this is only supported in the Java version for now. :('),
                                      SizedBox(height: 16),
                                      Text(
                                          'Please make sure this is disabled in the app and robot code during competition to save on network bandwidth.'),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('NO'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      enable = true;
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('YES'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                        widget.prefs.setBool('pplibClient', enable);
                        setState(() {
                          _pplibClient = enable;
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
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTextField(
      BuildContext context,
      String label,
      ValueChanged<String>? onSubmitted,
      String text,
      TextInputFormatter? formatter) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 40,
        width: 165,
        child: TextField(
          onSubmitted: (val) {
            if (onSubmitted != null && val.isNotEmpty) {
              onSubmitted.call(val);
            }
            _unfocus(context);
          },
          controller: TextEditingController(text: text)
            ..selection =
                TextSelection.fromPosition(TextPosition(offset: text.length)),
          inputFormatters: [
            if (formatter != null) formatter,
          ],
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
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
        const Text('Field Image:'),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          width: 165,
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
                    icon: const Icon(Icons.arrow_drop_down),
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
                      const DropdownMenuItem<FieldImage?>(
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
        Visibility(
          visible: _selectedField.isCustom,
          child: Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return EditFieldDialog(fieldImage: _selectedField);
                      });
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(80, 24),
                  padding: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Edit'),
              ),
              const SizedBox(width: 5),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Delete Custom Field Image'),
                          content: Text(
                              'Are you sure you want to delete the custom field "${_selectedField.name}"? This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();

                                Directory appDir =
                                    await getApplicationSupportDirectory();
                                Directory imagesDir = Directory(
                                    join(appDir.path, 'custom_fields'));
                                File imageFile = File(join(imagesDir.path,
                                    '${_selectedField.name}_${_selectedField.pixelsPerMeter.toStringAsFixed(2)}.${_selectedField.extension}'));

                                await imageFile.delete();
                                widget.fieldImages.remove(_selectedField);
                                setState(() {
                                  _selectedField = FieldImage.defaultField;
                                });
                                widget.onFieldSelected(FieldImage.defaultField);
                              },
                              child: const Text('Confirm'),
                            ),
                          ],
                        );
                      });
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(80, 24),
                  padding: const EdgeInsets.only(bottom: 12),
                  foregroundColor: colorScheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamColorPicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Team Color:'),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          width: 165,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Pick Team Color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: _teamColor,
                          enableAlpha: false,
                          hexInputBar: true,
                          onColorChanged: (Color color) {
                            setState(() {
                              _teamColor = color;
                            });
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _teamColor = Colors.indigo;
                              widget.onTeamColorChanged(_teamColor);
                            });
                          },
                          child: const Text('Reset'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onTeamColorChanged(_teamColor);
                          },
                          child: const Text('Confirm'),
                        ),
                      ],
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _teamColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Container(),
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
                      title: const Text('Failed to Import Field'),
                      content:
                          Text('Field with the name "$name" already exists.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
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
          String importedPath = join(imagesDir.path,
              '${name}_${pixelsPerMeter.toStringAsFixed(2)}.$imageExtension');

          await imageFile.copy(importedPath);

          FieldImage newField = FieldImage.custom(File(importedPath));

          widget.onFieldSelected(newField);
        });
      },
    );
  }
}
