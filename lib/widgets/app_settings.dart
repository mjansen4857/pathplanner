import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/dialogs/edit_field_dialog.dart';
import 'package:pathplanner/widgets/dialogs/import_field_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final ValueChanged<FieldImage> onFieldSelected;
  final List<FieldImage> fieldImages;
  final FieldImage selectedField;
  final SharedPreferences prefs;
  final ValueChanged<Color> onTeamColorChanged;

  const AppSettings({
    super.key,
    required this.onSettingsChanged,
    required this.onFieldSelected,
    required this.fieldImages,
    required this.selectedField,
    required this.prefs,
    required this.onTeamColorChanged,
  });

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  late num _defaultMaxVel;
  late num _defaultMaxAccel;
  late num _defaultMaxAngVel;
  late num _defaultMaxAngAccel;
  late num _defaultNominalVoltage;
  late bool _holonomicMode;
  late bool _hotReload;
  late FieldImage _selectedField;
  late Color _teamColor;
  late String _pplibClientHost;

  @override
  void initState() {
    super.initState();

    _defaultMaxVel = widget.prefs.getDouble(PrefsKeys.defaultMaxVel) ??
        Defaults.defaultMaxVel;
    _defaultMaxAccel = widget.prefs.getDouble(PrefsKeys.defaultMaxAccel) ??
        Defaults.defaultMaxAccel;
    _defaultMaxAngVel = widget.prefs.getDouble(PrefsKeys.defaultMaxAngVel) ??
        Defaults.defaultMaxAngVel;
    _defaultMaxAngAccel =
        widget.prefs.getDouble(PrefsKeys.defaultMaxAngAccel) ??
            Defaults.defaultMaxAngAccel;
    _defaultNominalVoltage =
        widget.prefs.getDouble(PrefsKeys.defaultNominalVoltage) ??
            Defaults.defaultNominalVoltage;
    _holonomicMode =
        widget.prefs.getBool(PrefsKeys.holonomicMode) ?? Defaults.holonomicMode;
    _hotReload = widget.prefs.getBool(PrefsKeys.hotReloadEnabled) ??
        Defaults.hotReloadEnabled;
    _selectedField = widget.selectedField;
    _teamColor =
        Color(widget.prefs.getInt(PrefsKeys.teamColor) ?? Defaults.teamColor);
    _pplibClientHost = widget.prefs.getString(PrefsKeys.ntServerAddress) ??
        Defaults.ntServerAddress;
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Default Constraints:'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialValue: _defaultMaxVel,
                  label: 'Max Velocity (M/S)',
                  minValue: 0.1,
                  onSubmitted: (value) {
                    if (value != null) {
                      widget.prefs
                          .setDouble(PrefsKeys.defaultMaxVel, value.toDouble());
                      setState(() {
                        _defaultMaxVel = value;
                      });
                    }
                    widget.onSettingsChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialValue: _defaultMaxAccel,
                  label: 'Max Acceleration (M/S²)',
                  minValue: 0.1,
                  onSubmitted: (value) {
                    if (value != null) {
                      widget.prefs.setDouble(
                          PrefsKeys.defaultMaxAccel, value.toDouble());
                      setState(() {
                        _defaultMaxAccel = value;
                      });
                    }
                    widget.onSettingsChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: NumberTextField(
                      initialValue: _defaultMaxAngVel,
                      label: 'Max Angular Velocity (Deg/S)',
                      minValue: 0.1,
                      onSubmitted: (value) {
                        if (value != null) {
                          widget.prefs.setDouble(
                              PrefsKeys.defaultMaxAngVel, value.toDouble());
                          setState(() {
                            _defaultMaxAngVel = value;
                          });
                        }
                        widget.onSettingsChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NumberTextField(
                      initialValue: _defaultMaxAngAccel,
                      label: 'Max Angular Accel (Deg/S²)',
                      minValue: 0.1,
                      onSubmitted: (value) {
                        if (value != null) {
                          widget.prefs.setDouble(
                              PrefsKeys.defaultMaxAngAccel, value.toDouble());
                          setState(() {
                            _defaultMaxAngAccel = value;
                          });
                        }
                        widget.onSettingsChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: NumberTextField(
                      initialValue: _defaultNominalVoltage,
                      label: 'Nominal Voltage (Volts)',
                      minValue: 6.0,
                      maxValue: 13.0,
                      arrowKeyIncrement: 0.1,
                      onSubmitted: (value) {
                        if (value != null) {
                          widget.prefs.setDouble(
                              PrefsKeys.defaultNominalVoltage,
                              value.toDouble());
                          setState(() {
                            _defaultNominalVoltage = value;
                          });
                        }
                        widget.onSettingsChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildFieldImageDropdown(context)),
              const SizedBox(width: 8),
              Expanded(child: _buildThemeColorPicker(context)),
            ],
          ),
          const SizedBox(height: 2),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PPLib Telemetry:'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      context,
                      'roboRIO IP (10.TE.AM.2)',
                      (value) {
                        // Check if valid IP
                        try {
                          Uri.parseIPv4Address(value);

                          widget.prefs
                              .setString(PrefsKeys.ntServerAddress, value);
                          setState(() {
                            _pplibClientHost = value;
                          });
                          widget.onSettingsChanged();
                        } catch (_) {
                          setState(() {});
                        }
                      },
                      _pplibClientHost,
                      null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
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
                  FilterChip.elevated(
                    label: const Text('Holonomic Mode'),
                    selected: _holonomicMode,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    onSelected: (value) {
                      widget.prefs.setBool(PrefsKeys.holonomicMode, value);
                      setState(() {
                        _holonomicMode = value;
                      });
                      widget.onSettingsChanged();
                    },
                  ),
                  FilterChip.elevated(
                    label: const Text('Hot Reload'),
                    selected: _hotReload,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    onSelected: (value) {
                      widget.prefs.setBool(PrefsKeys.hotReloadEnabled, value);
                      setState(() {
                        _hotReload = value;
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
    );
  }

  Widget _buildTextField(
      BuildContext context,
      String label,
      ValueChanged<String>? onSubmitted,
      String text,
      TextInputFormatter? formatter) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    final controller = TextEditingController(text: text)
      ..selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));

    return SizedBox(
      height: 42,
      child: Focus(
        skipTraversal: true,
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            if (onSubmitted != null && controller.text.isNotEmpty) {
              onSubmitted.call(controller.text);
            }
          }
        },
        child: TextField(
          controller: controller,
          inputFormatters: [
            if (formatter != null) formatter,
          ],
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline),
              ),
              child: ExcludeFocus(
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButton<FieldImage?>(
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
                      }),
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

  Widget _buildThemeColorPicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Theme Color:'),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.transparent,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Pick Theme Color'),
                      content: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: _teamColor,
                            enableAlpha: false,
                            hexInputBar: true,
                            onColorChanged: (Color color) {
                              setState(() {
                                _teamColor = color;
                              });
                              widget.onTeamColorChanged(_teamColor);
                            },
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _teamColor = const Color(Defaults.teamColor);
                              widget.onTeamColorChanged(_teamColor);
                            });
                          },
                          child: const Text('Reset'),
                        ),
                        TextButton(
                          onPressed: Navigator.of(context).pop,
                          child: const Text('Close'),
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
