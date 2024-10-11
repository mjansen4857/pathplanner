import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/dialogs/edit_field_dialog.dart';
import 'package:pathplanner/widgets/dialogs/import_field_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final ValueChanged<FieldImage> onFieldSelected;
  final List<FieldImage> fieldImages;
  final FieldImage selectedField;
  final SharedPreferences prefs;
  final ValueChanged<Color> onTeamColorChanged;

  const SettingsDialog(
      {required this.onSettingsChanged,
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
  late num _width;
  late num _length;
  late num _mass;
  late num _moi;
  late num _wheelbase;
  late num _trackwidth;
  late num _wheelRadius;
  late num _driveGearing;
  late num _maxDriveSpeed;
  late num _wheelCOF;
  late String _driveMotor;
  late num _currentLimit;
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

  late num _optimalCurrentLimit;
  late num _maxAccel;

  @override
  void initState() {
    super.initState();

    _width =
        widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth;
    _length =
        widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength;
    _mass = widget.prefs.getDouble(PrefsKeys.robotMass) ?? Defaults.robotMass;
    _moi = widget.prefs.getDouble(PrefsKeys.robotMOI) ?? Defaults.robotMOI;
    _wheelbase = widget.prefs.getDouble(PrefsKeys.robotWheelbase) ??
        Defaults.robotWheelbase;
    _trackwidth = widget.prefs.getDouble(PrefsKeys.robotTrackwidth) ??
        Defaults.robotTrackwidth;
    _wheelRadius = widget.prefs.getDouble(PrefsKeys.driveWheelRadius) ??
        Defaults.driveWheelRadius;
    _driveGearing =
        widget.prefs.getDouble(PrefsKeys.driveGearing) ?? Defaults.driveGearing;
    _maxDriveSpeed = widget.prefs.getDouble(PrefsKeys.maxDriveSpeed) ??
        Defaults.maxDriveSpeed;
    _wheelCOF = widget.prefs.getDouble(PrefsKeys.wheelCOF) ?? Defaults.wheelCOF;
    _driveMotor =
        widget.prefs.getString(PrefsKeys.driveMotor) ?? Defaults.driveMotor;
    _currentLimit = widget.prefs.getDouble(PrefsKeys.driveCurrentLimit) ??
        Defaults.driveCurrentLimit;

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

    _optimalCurrentLimit = _calculateOptimalCurrentLimit();
    _maxAccel = _calculateMaxAccel();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 740,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Robot Config:'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: NumberTextField(
                          initialValue: _width,
                          minValue: 0.0,
                          label: 'Bumper Width (M)',
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.robotWidth, value.toDouble());
                              setState(() {
                                _width = value;
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberTextField(
                          initialValue: _length,
                          minValue: 0.0,
                          label: 'Bumper Length (M)',
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.robotLength, value.toDouble());
                              setState(() {
                                _length = value;
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NumberTextField(
                          initialValue: _mass,
                          label: 'Robot Mass (KG)',
                          minValue: 0.0,
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.robotMass, value.toDouble());
                              setState(() {
                                _mass = value;
                                _optimalCurrentLimit =
                                    _calculateOptimalCurrentLimit();
                                _maxAccel = _calculateMaxAccel();
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberTextField(
                          initialValue: _moi,
                          label: 'Robot MOI (KG*M²)',
                          minValue: 0.0,
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.robotMOI, value.toDouble());
                              setState(() {
                                _moi = value;
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NumberTextField(
                          initialValue: _wheelbase,
                          label: 'Wheelbase (M)',
                          enabled: _holonomicMode,
                          minValue: 0.0,
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.robotWheelbase, value.toDouble());
                              setState(() {
                                _wheelbase = value;
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberTextField(
                          initialValue: _trackwidth,
                          label: 'Trackwidth (M)',
                          minValue: 0.0,
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.robotTrackwidth, value.toDouble());
                              setState(() {
                                _trackwidth = value;
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Module Config:'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: NumberTextField(
                          initialValue: _wheelRadius,
                          label: 'Wheel Radius (M)',
                          minValue: 0.0,
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.driveWheelRadius, value.toDouble());
                              setState(() {
                                _wheelRadius = value;
                                _optimalCurrentLimit =
                                    _calculateOptimalCurrentLimit();
                                _maxAccel = _calculateMaxAccel();
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberTextField(
                          initialValue: _driveGearing,
                          label: 'Drive Gearing',
                          minValue: 1.0,
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.driveGearing, value.toDouble());
                              setState(() {
                                _driveGearing = value;
                                _optimalCurrentLimit =
                                    _calculateOptimalCurrentLimit();
                                _maxAccel = _calculateMaxAccel();
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NumberTextField(
                          initialValue: _maxDriveSpeed,
                          label: 'True Max Drive Speed (M/S)',
                          minValue: 0.0,
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.maxDriveSpeed, value.toDouble());
                              setState(() {
                                _maxDriveSpeed = value;
                                _optimalCurrentLimit =
                                    _calculateOptimalCurrentLimit();
                                _maxAccel = _calculateMaxAccel();
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberTextField(
                          initialValue: _wheelCOF,
                          minValue: 0.0,
                          label: 'Wheel COF',
                          onSubmitted: (value) {
                            if (value != null) {
                              widget.prefs.setDouble(
                                  PrefsKeys.wheelCOF, value.toDouble());
                              setState(() {
                                _wheelCOF = value;
                                _optimalCurrentLimit =
                                    _calculateOptimalCurrentLimit();
                                _maxAccel = _calculateMaxAccel();
                              });
                            }
                            widget.onSettingsChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Column(
                                  children: [
                                    const SizedBox(height: 9),
                                    SizedBox(
                                      height: 49,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: colorScheme.outline),
                                          ),
                                          child: ExcludeFocus(
                                            child: ButtonTheme(
                                              alignedDropdown: true,
                                              child: DropdownButton<String>(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                value: _driveMotor,
                                                isExpanded: true,
                                                underline: Container(),
                                                menuMaxHeight: 250,
                                                icon: const Icon(
                                                    Icons.arrow_drop_down),
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color:
                                                        colorScheme.onSurface),
                                                onChanged: (String? newValue) {
                                                  if (newValue != null) {
                                                    setState(() {
                                                      _driveMotor = newValue;
                                                      _optimalCurrentLimit =
                                                          _calculateOptimalCurrentLimit();
                                                      _maxAccel =
                                                          _calculateMaxAccel();
                                                    });
                                                    widget.prefs.setString(
                                                        PrefsKeys.driveMotor,
                                                        _driveMotor);
                                                    widget.onSettingsChanged();
                                                  }
                                                },
                                                items: const [
                                                  DropdownMenuItem<String>(
                                                    value: 'krakenX60',
                                                    child: Text('Kraken X60'),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'krakenX60FOC',
                                                    child:
                                                        Text('Kraken X60 FOC'),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'falcon500',
                                                    child: Text('Falcon 500'),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'falcon500FOC',
                                                    child:
                                                        Text('Falcon 500 FOC'),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'vortex',
                                                    child: Text('NEO Vortex'),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'NEO',
                                                    child: Text('NEO'),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'CIM',
                                                    child: Text('CIM'),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'miniCIM',
                                                    child: Text('MiniCIM'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Tooltip(
                                      richMessage: WidgetSpan(
                                        alignment:
                                            PlaceholderAlignment.baseline,
                                        baseline: TextBaseline.alphabetic,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                              maxWidth: 250),
                                          child: Text(
                                            'The real max acceleration of the robot, calculated from the above values. If this is too slow, ensure that your True Max Drive Speed is correct. This should be the actual measured max speed of the robot under load.',
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.help_outline,
                                            size: 16.0,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 2),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2),
                                            child: Text(
                                              'Max Accel: ${_maxAccel.toStringAsFixed(1)}M/S²',
                                              style: TextStyle(
                                                color: (_maxAccel < 3)
                                                    ? colorScheme.error
                                                    : colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 2, top: 12),
                                  child: Container(
                                    width: 78,
                                    height: 3,
                                    color: colorScheme.surface,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 8, top: 3),
                                  child: Text(
                                    'Drive Motor',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),
                            NumberTextField(
                              initialValue: _currentLimit,
                              label: 'Drive Current Limit (A)',
                              minValue: 0.0,
                              precision: 0,
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.driveCurrentLimit,
                                      value.roundToDouble());
                                  setState(() {
                                    _currentLimit = value.roundToDouble();
                                    _maxAccel = _calculateMaxAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                            const SizedBox(height: 4),
                            Tooltip(
                              richMessage: WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 250),
                                  child: Text(
                                    'The maximum current limit that would still prevent the wheels from slipping under maximum acceleration.',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(4)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.help_outline,
                                    size: 16.0,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      'Max Optimal Limit: ${_optimalCurrentLimit.toStringAsFixed(0)}A',
                                      style: TextStyle(
                                        color: (_optimalCurrentLimit.round() <
                                                _currentLimit.round())
                                            ? colorScheme.error
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
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
                              widget.prefs.setDouble(
                                  PrefsKeys.defaultMaxVel, value.toDouble());
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
                                      PrefsKeys.defaultMaxAngVel,
                                      value.toDouble());
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
                                      PrefsKeys.defaultMaxAngAccel,
                                      value.toDouble());
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
                      Expanded(child: _buildTeamColorPicker(context)),
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
                              'Host IP (localhost = 127.0.0.1)',
                              (value) {
                                // Check if valid IP
                                try {
                                  Uri.parseIPv4Address(value);

                                  widget.prefs.setString(
                                      PrefsKeys.ntServerAddress, value);
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
                            onSelected: (value) {
                              widget.prefs
                                  .setBool(PrefsKeys.holonomicMode, value);
                              setState(() {
                                _holonomicMode = value;
                                _optimalCurrentLimit =
                                    _calculateOptimalCurrentLimit();
                                _maxAccel = _calculateMaxAccel();
                              });
                              widget.onSettingsChanged();
                            },
                          ),
                          FilterChip.elevated(
                            label: const Text('Hot Reload'),
                            selected: _hotReload,
                            onSelected: (value) {
                              widget.prefs
                                  .setBool(PrefsKeys.hotReloadEnabled, value);
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

  Widget _buildTeamColorPicker(BuildContext context) {
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

  num _calculateOptimalCurrentLimit() {
    final int numModules = _holonomicMode ? 4 : 2;
    final int numMotors = _holonomicMode ? 1 : 2;
    final DCMotor driveMotor =
        DCMotor.fromString(_driveMotor, numMotors).withReduction(_driveGearing);
    final maxVelCurrent = min(
        driveMotor.getCurrent(_maxDriveSpeed / _wheelRadius, 12.0),
        _currentLimit * numMotors);
    final torqueLoss = max(driveMotor.getTorque(maxVelCurrent), 0.0);
    final num moduleFrictionForce = (_wheelCOF * (_mass * 9.8)) / numModules;
    final num maxFrictionTorque = moduleFrictionForce * _wheelRadius;
    return ((maxFrictionTorque + torqueLoss) / driveMotor.kTNMPerAmp) /
        numMotors;
  }

  num _calculateMaxAccel() {
    final int numModules = _holonomicMode ? 4 : 2;
    final int numMotors = _holonomicMode ? 1 : 2;
    final DCMotor driveMotor =
        DCMotor.fromString(_driveMotor, numMotors).withReduction(_driveGearing);

    final maxVelCurrent = min(
        driveMotor.getCurrent(_maxDriveSpeed / _wheelRadius, 12.0),
        _currentLimit * numMotors);
    final torqueLoss = max(driveMotor.getTorque(maxVelCurrent), 0.0);
    final num moduleFrictionForce = (_wheelCOF * (_mass * 9.8)) / numModules;
    final maxCurrent =
        min(driveMotor.getCurrent(0.0, 12.0), (_currentLimit * numMotors));
    final maxTorque = ((maxCurrent * driveMotor.kTNMPerAmp) - torqueLoss);
    final maxForce = min(maxTorque / _wheelRadius, moduleFrictionForce);

    if (maxForce > 0) {
      return (maxForce * numModules) / _mass;
    } else {
      return 0.0;
    }
  }
}
