import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_features/circle_feature.dart';
import 'package:pathplanner/robot_features/feature.dart';
import 'package:pathplanner/robot_features/line_feature.dart';
import 'package:pathplanner/robot_features/rounded_rect_feature.dart';
import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/units.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RobotConfigSettings extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final SharedPreferences prefs;

  const RobotConfigSettings({
    super.key,
    required this.onSettingsChanged,
    required this.prefs,
  });

  @override
  State<RobotConfigSettings> createState() => _RobotConfigSettingsState();
}

class _RobotConfigSettingsState extends State<RobotConfigSettings> {
  late final bool _holonomicMode;
  late num _bumperWidth;
  late num _bumperLength;
  late num _bumperOffsetX;
  late num _bumperOffsetY;
  late num _mass;
  late num _moi;
  late num _trackwidth;
  late num _wheelRadius;
  late num _driveGearing;
  late num _maxDriveSpeed;
  late num _wheelCOF;
  late String _driveMotor;
  late num _currentLimit;
  late List<Translation2d> _modulePositions;
  final List<Feature> _features = [];

  late num _optimalCurrentLimit;
  late num _maxAccel;
  late num _maxAngAccel;

  @override
  void initState() {
    super.initState();

    _holonomicMode =
        widget.prefs.getBool(PrefsKeys.holonomicMode) ?? Defaults.holonomicMode;
    _bumperWidth =
        widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth;
    _bumperLength =
        widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength;
    _bumperOffsetX = widget.prefs.getDouble(PrefsKeys.bumperOffsetX) ??
        Defaults.bumperOffsetX;
    _bumperOffsetY = widget.prefs.getDouble(PrefsKeys.bumperOffsetY) ??
        Defaults.bumperOffsetY;
    _mass = widget.prefs.getDouble(PrefsKeys.robotMass) ?? Defaults.robotMass;
    _moi = widget.prefs.getDouble(PrefsKeys.robotMOI) ?? Defaults.robotMOI;
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

    _modulePositions = [
      Translation2d(
          widget.prefs.getDouble(PrefsKeys.flModuleX) ?? Defaults.flModuleX,
          widget.prefs.getDouble(PrefsKeys.flModuleY) ?? Defaults.flModuleY),
      Translation2d(
          widget.prefs.getDouble(PrefsKeys.frModuleX) ?? Defaults.frModuleX,
          widget.prefs.getDouble(PrefsKeys.frModuleY) ?? Defaults.frModuleY),
      Translation2d(
          widget.prefs.getDouble(PrefsKeys.blModuleX) ?? Defaults.blModuleX,
          widget.prefs.getDouble(PrefsKeys.blModuleY) ?? Defaults.blModuleY),
      Translation2d(
          widget.prefs.getDouble(PrefsKeys.brModuleX) ?? Defaults.brModuleX,
          widget.prefs.getDouble(PrefsKeys.brModuleY) ?? Defaults.brModuleY),
    ];

    for (String featureJson
        in widget.prefs.getStringList(PrefsKeys.robotFeatures) ??
            Defaults.robotFeatures) {
      try {
        _features.add(Feature.fromJson(jsonDecode(featureJson))!);
      } catch (_) {
        // Ignore and skip loading this feature
      }
    }

    _optimalCurrentLimit = _calculateOptimalCurrentLimit();
    _maxAccel = _calculateMaxAccel();
    _maxAngAccel = _calculateMaxAngAccel();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Theme(
            data: Theme.of(context).copyWith(
              scrollbarTheme: ScrollbarThemeData(
                thumbVisibility: WidgetStateProperty.all<bool>(true),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
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
                                  _maxAngAccel = _calculateMaxAngAccel();
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
                                  _maxAngAccel = _calculateMaxAngAccel();
                                });
                              }
                              widget.onSettingsChanged();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!_holonomicMode) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: NumberTextField(
                              initialValue: _trackwidth,
                              minValue: 0.01,
                              label: 'Trackwidth (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.robotTrackwidth,
                                      value.toDouble());
                                  setState(() {
                                    _trackwidth = value;
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('Bumpers:'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: NumberTextField(
                            initialValue: _bumperWidth,
                            minValue: 0.0,
                            label: 'Bumper Width (M)',
                            onSubmitted: (value) {
                              if (value != null) {
                                widget.prefs.setDouble(
                                    PrefsKeys.robotWidth, value.toDouble());
                                setState(() {
                                  _bumperWidth = value;
                                });
                              }
                              widget.onSettingsChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NumberTextField(
                            initialValue: _bumperLength,
                            minValue: 0.0,
                            label: 'Bumper Length (M)',
                            onSubmitted: (value) {
                              if (value != null) {
                                widget.prefs.setDouble(
                                    PrefsKeys.robotLength, value.toDouble());
                                setState(() {
                                  _bumperLength = value;
                                });
                              }
                              widget.onSettingsChanged();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: NumberTextField(
                            initialValue: _bumperOffsetX,
                            label: 'Bumper Offset X (M)',
                            onSubmitted: (value) {
                              if (value != null) {
                                widget.prefs.setDouble(
                                    PrefsKeys.bumperOffsetX, value.toDouble());
                                setState(() {
                                  _bumperOffsetX = value;
                                });
                              }
                              widget.onSettingsChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NumberTextField(
                            initialValue: _bumperOffsetY,
                            label: 'Bumper Offset Y (M)',
                            onSubmitted: (value) {
                              if (value != null) {
                                widget.prefs.setDouble(
                                    PrefsKeys.bumperOffsetY, value.toDouble());
                                setState(() {
                                  _bumperOffsetY = value;
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
                                    PrefsKeys.driveWheelRadius,
                                    value.toDouble());
                                setState(() {
                                  _wheelRadius = value;
                                  _optimalCurrentLimit =
                                      _calculateOptimalCurrentLimit();
                                  _maxAccel = _calculateMaxAccel();
                                  _maxAngAccel = _calculateMaxAngAccel();
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
                                  _maxAngAccel = _calculateMaxAngAccel();
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
                                  _maxAngAccel = _calculateMaxAngAccel();
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
                                  _maxAngAccel = _calculateMaxAngAccel();
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
                                                      color: colorScheme
                                                          .onSurface),
                                                  onChanged:
                                                      (String? newValue) {
                                                    if (newValue != null) {
                                                      setState(() {
                                                        _driveMotor = newValue;
                                                        _optimalCurrentLimit =
                                                            _calculateOptimalCurrentLimit();
                                                        _maxAccel =
                                                            _calculateMaxAccel();
                                                        _maxAngAccel =
                                                            _calculateMaxAngAccel();
                                                      });
                                                      widget.prefs.setString(
                                                          PrefsKeys.driveMotor,
                                                          _driveMotor);
                                                      widget
                                                          .onSettingsChanged();
                                                    }
                                                  },
                                                  items: const [
                                                    DropdownMenuItem<String>(
                                                      value: 'krakenX60',
                                                      child: Text('Kraken X60'),
                                                    ),
                                                    DropdownMenuItem<String>(
                                                      value: 'krakenX60FOC',
                                                      child: Text(
                                                          'Kraken X60 FOC'),
                                                    ),
                                                    DropdownMenuItem<String>(
                                                      value: 'falcon500',
                                                      child: Text('Falcon 500'),
                                                    ),
                                                    DropdownMenuItem<String>(
                                                      value: 'falcon500FOC',
                                                      child: Text(
                                                          'Falcon 500 FOC'),
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
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: NumberTextField(
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
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_holonomicMode) ...[
                      const SizedBox(height: 12),
                      const Text('Module Offsets:'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: NumberTextField(
                              initialValue: _modulePositions[0].x,
                              minValue: 0.0,
                              label: 'Front Left X (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.flModuleX, value.toDouble());
                                  setState(() {
                                    _modulePositions[0] = Translation2d(
                                        value, _modulePositions[0].y);
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NumberTextField(
                              initialValue: _modulePositions[0].y,
                              minValue: 0.0,
                              label: 'Front Left Y (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.flModuleY, value.toDouble());
                                  setState(() {
                                    _modulePositions[0] = Translation2d(
                                        _modulePositions[0].x, value);
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: NumberTextField(
                              initialValue: _modulePositions[1].x,
                              minValue: 0.0,
                              label: 'Front Right X (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.frModuleX, value.toDouble());
                                  setState(() {
                                    _modulePositions[1] = Translation2d(
                                        value, _modulePositions[1].y);
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NumberTextField(
                              initialValue: _modulePositions[1].y,
                              maxValue: 0.0,
                              label: 'Front Right Y (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.frModuleY, value.toDouble());
                                  setState(() {
                                    _modulePositions[1] = Translation2d(
                                        _modulePositions[1].x, value);
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: NumberTextField(
                              initialValue: _modulePositions[2].x,
                              maxValue: 0.0,
                              label: 'Back Left X (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.blModuleX, value.toDouble());
                                  setState(() {
                                    _modulePositions[2] = Translation2d(
                                        value, _modulePositions[2].y);
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NumberTextField(
                              initialValue: _modulePositions[2].y,
                              minValue: 0.0,
                              label: 'Back Left Y (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.blModuleY, value.toDouble());
                                  setState(() {
                                    _modulePositions[2] = Translation2d(
                                        _modulePositions[2].x, value);
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: NumberTextField(
                              initialValue: _modulePositions[3].x,
                              maxValue: 0.0,
                              label: 'Back Right X (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.brModuleX, value.toDouble());
                                  setState(() {
                                    _modulePositions[3] = Translation2d(
                                        value, _modulePositions[3].y);
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NumberTextField(
                              initialValue: _modulePositions[3].y,
                              maxValue: 0.0,
                              label: 'Back Right Y (M)',
                              onSubmitted: (value) {
                                if (value != null) {
                                  widget.prefs.setDouble(
                                      PrefsKeys.brModuleY, value.toDouble());
                                  setState(() {
                                    _modulePositions[3] = Translation2d(
                                        _modulePositions[3].x, value);
                                    _maxAngAccel = _calculateMaxAngAccel();
                                  });
                                }
                                widget.onSettingsChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Robot Features:'),
                        ),
                        PopupMenuButton(
                          tooltip: 'Add Feature',
                          icon: Icon(Icons.add, color: colorScheme.primary),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'rounded_rect',
                              child: Text('Rectangle'),
                            ),
                            PopupMenuItem(
                              value: 'circle',
                              child: Text('Circle'),
                            ),
                            PopupMenuItem(
                              value: 'line',
                              child: Text('Line'),
                            ),
                          ],
                          onSelected: (value) {
                            setState(() {
                              switch (value) {
                                case 'rounded_rect':
                                  _features.add(
                                      RoundedRectFeature(name: 'Rectangle'));
                                  break;
                                case 'circle':
                                  _features.add(CircleFeature(name: 'Circle'));
                                  break;
                                case 'line':
                                  _features.add(LineFeature(name: 'Line'));
                                  break;
                              }
                            });
                            _saveFeatures();
                            widget.onSettingsChanged();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (int i = 0; i < _features.length; i++)
                      _buildFeatureWidget(i, colorScheme),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: Card(
                  elevation: 1.0,
                  color: colorScheme.surface,
                  surfaceTintColor: colorScheme.surfaceTint,
                  child: CustomPaint(
                    painter: _RobotPainter(
                      colorScheme: colorScheme,
                      bumperWidth: _bumperWidth,
                      bumperLength: _bumperLength,
                      bumperOffsetX: _bumperOffsetX,
                      bumperOffsetY: _bumperOffsetY,
                      modulePositions: _holonomicMode ? _modulePositions : [],
                      features: _features,
                    ),
                  ),
                ),
              ),
              Tooltip(
                richMessage: WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Text(
                      'The real max acceleration of the robot, calculated from the config values. If this is too slow, ensure that your True Max Drive Speed is correct. This should be the actual measured max speed of the robot under load.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
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
                        'Max Linear Acceleration: ${_maxAccel.toStringAsFixed(1)}M/S²',
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
              Tooltip(
                richMessage: WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Text(
                      'The real max angular acceleration of the robot, calculated from the config values.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
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
                        'Max Angular Acceleration: ${_maxAngAccel.toStringAsFixed(0)}°/S²',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                richMessage: WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
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
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
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
                        'Max Optimal Current Limit: ${_optimalCurrentLimit.toStringAsFixed(0)}A',
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
    );
  }

  Widget _buildFeatureWidget(int idx, ColorScheme colorScheme) {
    return switch (_features[idx].type) {
      'rounded_rect' => _buildRectFeatureCard(idx, colorScheme),
      'circle' => _buildCircleFeatureCard(idx, colorScheme),
      'line' => _buildLineFeatureCard(idx, colorScheme),
      _ => Container(),
    };
  }

  Widget _buildRectFeatureCard(int idx, ColorScheme colorScheme) {
    RoundedRectFeature f = _features[idx] as RoundedRectFeature;

    return TreeCardNode(
      title: Row(
        children: [
          RenamableTitle(
            title: f.name,
            onRename: (value) {
              if (value.isNotEmpty) {
                setState(() {
                  f.name = value;
                });
              }
            },
          ),
          Expanded(child: Container()),
        ],
      ),
      trailing: Tooltip(
        message: 'Delete Feature',
        waitDuration: const Duration(seconds: 1),
        child: IconButton(
          icon: const Icon(Icons.delete_forever),
          color: colorScheme.error,
          onPressed: () {
            setState(() {
              _features.removeAt(idx);
            });
            _saveFeatures();
            widget.onSettingsChanged();
          },
        ),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: NumberTextField(
                initialValue: f.center.x,
                label: 'Center X (M)',
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.center = Translation2d(value, f.center.y);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberTextField(
                initialValue: f.center.y,
                label: 'Center Y (M)',
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.center = Translation2d(f.center.x, value);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumberTextField(
                initialValue: f.size.width,
                label: 'Width (M)',
                minValue: 0.0,
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.size = Size(value.toDouble(), f.size.height);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberTextField(
                initialValue: f.size.height,
                label: 'Length (M)',
                minValue: 0.0,
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.size = Size(f.size.width, value.toDouble());
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumberTextField(
                initialValue: f.borderRadius,
                label: 'Border Radius (M)',
                minValue: 0.0,
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.borderRadius = value;
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberTextField(
                initialValue: f.strokeWidth,
                label: 'Stroke Width (M)',
                minValue: 0.0,
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.strokeWidth = value;
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilterChip.elevated(
          label: const Text('Filled'),
          selected: f.filled,
          backgroundColor: colorScheme.surfaceContainerLow,
          onSelected: (value) {
            setState(() {
              f.filled = value;
            });
            _saveFeatures();
            widget.onSettingsChanged();
          },
        ),
      ],
    );
  }

  Widget _buildCircleFeatureCard(int idx, ColorScheme colorScheme) {
    CircleFeature f = _features[idx] as CircleFeature;

    return TreeCardNode(
      title: Row(
        children: [
          RenamableTitle(
            title: f.name,
            onRename: (value) {
              if (value.isNotEmpty) {
                setState(() {
                  f.name = value;
                });
              }
            },
          ),
          Expanded(child: Container()),
        ],
      ),
      trailing: Tooltip(
        message: 'Delete Feature',
        waitDuration: const Duration(seconds: 1),
        child: IconButton(
          icon: const Icon(Icons.delete_forever),
          color: colorScheme.error,
          onPressed: () {
            setState(() {
              _features.removeAt(idx);
            });
            _saveFeatures();
            widget.onSettingsChanged();
          },
        ),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: NumberTextField(
                initialValue: f.center.x,
                label: 'Center X (M)',
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.center = Translation2d(value, f.center.y);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberTextField(
                initialValue: f.center.y,
                label: 'Center Y (M)',
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.center = Translation2d(f.center.x, value);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumberTextField(
                initialValue: f.radius,
                label: 'Radius (M)',
                minValue: 0.0,
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.radius = value;
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberTextField(
                initialValue: f.strokeWidth,
                label: 'Stroke Width (M)',
                minValue: 0.0,
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.strokeWidth = value;
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilterChip.elevated(
          label: const Text('Filled'),
          selected: f.filled,
          backgroundColor: colorScheme.surfaceContainerLow,
          onSelected: (value) {
            setState(() {
              f.filled = value;
            });
            _saveFeatures();
            widget.onSettingsChanged();
          },
        ),
      ],
    );
  }

  Widget _buildLineFeatureCard(int idx, ColorScheme colorScheme) {
    LineFeature f = _features[idx] as LineFeature;

    return TreeCardNode(
      title: Row(
        children: [
          RenamableTitle(
            title: f.name,
            onRename: (value) {
              if (value.isNotEmpty) {
                setState(() {
                  f.name = value;
                });
              }
            },
          ),
          Expanded(child: Container()),
        ],
      ),
      trailing: Tooltip(
        message: 'Delete Feature',
        waitDuration: const Duration(seconds: 1),
        child: IconButton(
          icon: const Icon(Icons.delete_forever),
          color: colorScheme.error,
          onPressed: () {
            setState(() {
              _features.removeAt(idx);
            });
            _saveFeatures();
            widget.onSettingsChanged();
          },
        ),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: NumberTextField(
                initialValue: f.start.x,
                label: 'Start X (M)',
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.start = Translation2d(value, f.start.y);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberTextField(
                initialValue: f.start.y,
                label: 'Start Y (M)',
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.start = Translation2d(f.start.x, value);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumberTextField(
                initialValue: f.end.x,
                label: 'End X (M)',
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.end = Translation2d(value, f.end.y);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberTextField(
                initialValue: f.end.y,
                label: 'End Y (M)',
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.end = Translation2d(f.end.x, value);
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumberTextField(
                initialValue: f.strokeWidth,
                label: 'Stroke Width (M)',
                minValue: 0.0,
                onSubmitted: (value) {
                  if (value != null) {
                    setState(() {
                      f.strokeWidth = value;
                    });
                    _saveFeatures();
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _saveFeatures() {
    widget.prefs.setStringList(PrefsKeys.robotFeatures, [
      for (Feature f in _features) jsonEncode(f.toJson()),
    ]);
  }

  num _calculateOptimalCurrentLimit() {
    final int numModules = _holonomicMode ? _modulePositions.length : 2;
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
    final int numModules = _holonomicMode ? _modulePositions.length : 2;
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

  num _calculateMaxAngAccel() {
    final int numModules = _holonomicMode ? _modulePositions.length : 2;
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

    num chassisTorque = 0.0;
    if (_holonomicMode) {
      for (Translation2d m in _modulePositions) {
        chassisTorque += maxForce * m.norm;
      }
    } else {
      chassisTorque = maxForce * _trackwidth;
    }

    if (maxForce > 0) {
      return Units.radiansToDegrees(chassisTorque / _moi);
    } else {
      return 0.0;
    }
  }
}

class _RobotPainter extends CustomPainter {
  final ColorScheme colorScheme;
  final num bumperWidth;
  final num bumperLength;
  final num bumperOffsetX;
  final num bumperOffsetY;
  final List<Translation2d> modulePositions;
  final List<Feature> features;

  const _RobotPainter({
    required this.colorScheme,
    required this.bumperWidth,
    required this.bumperLength,
    required this.modulePositions,
    required this.bumperOffsetX,
    required this.bumperOffsetY,
    required this.features,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.secondary;

    double pixelsPerMeter =
        min((size.width - 64) / bumperWidth, (size.height - 64) / bumperLength);

    Offset center = Offset(size.width / 2.0, size.height / 2.0);
    Offset bumperOffsetPixels =
        Offset(bumperOffsetX * pixelsPerMeter, -bumperOffsetY * pixelsPerMeter);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pi / 2);
    canvas.translate(-bumperOffsetPixels.dx, -bumperOffsetPixels.dy);

    canvas.drawCircle(Offset.zero, 1.5, paint);

    for (final feature in features) {
      feature.draw(canvas, pixelsPerMeter, colorScheme.primary);
    }

    PathPainterUtil.paintRobotOutlinePixels(
      Offset.zero,
      0.0,
      Size(bumperWidth * pixelsPerMeter, bumperLength * pixelsPerMeter),
      bumperOffsetPixels,
      8,
      0.02 * pixelsPerMeter,
      0.075 * pixelsPerMeter,
      canvas,
      colorScheme.primary,
      colorScheme.surfaceContainer,
    );

    List<Offset> modulePositionsPixels = [
      for (Translation2d p in modulePositions)
        Offset(p.x * pixelsPerMeter, -p.y * pixelsPerMeter)
    ];

    // PathPainterUtil.paintRobotModules(modulePoses, fieldImage, scale, canvas, color)
    PathPainterUtil.paintRobotModulesPixels(
      modulePositionsPixels,
      List.generate(modulePositionsPixels.length, (_) => 0.0),
      0.1 * pixelsPerMeter,
      0.04 * pixelsPerMeter,
      2,
      canvas,
      colorScheme.primary,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
