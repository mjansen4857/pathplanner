import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/units.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
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
  late List<Translation2d> _modulePositions;

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

    _modulePositions = [
      Translation2d(_wheelbase / 2, _trackwidth / 2),
      Translation2d(_wheelbase / 2, -_trackwidth / 2),
      Translation2d(-_wheelbase / 2, _trackwidth / 2),
      Translation2d(-_wheelbase / 2, -_trackwidth / 2),
    ];

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
          child: ListView(
            children: [
              const Text('Robot Config:'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: NumberTextField(
                      initialValue: _mass,
                      label: 'Robot Mass (KG)',
                      minValue: 0.0,
                      onSubmitted: (value) {
                        if (value != null) {
                          widget.prefs
                              .setDouble(PrefsKeys.robotMass, value.toDouble());
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
                          widget.prefs
                              .setDouble(PrefsKeys.robotMOI, value.toDouble());
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
              const SizedBox(height: 12),
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
                          widget.prefs
                              .setDouble(PrefsKeys.wheelCOF, value.toDouble());
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
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
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
                                                color: colorScheme.onSurface),
                                            onChanged: (String? newValue) {
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
                                                child: Text('Kraken X60 FOC'),
                                              ),
                                              DropdownMenuItem<String>(
                                                value: 'falcon500',
                                                child: Text('Falcon 500'),
                                              ),
                                              DropdownMenuItem<String>(
                                                value: 'falcon500FOC',
                                                child: Text('Falcon 500 FOC'),
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
                              padding: const EdgeInsets.only(left: 2, top: 12),
                              child: Container(
                                width: 78,
                                height: 3,
                                color: colorScheme.surface,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 3),
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
                            widget.prefs.setDouble(PrefsKeys.driveCurrentLimit,
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
            ],
          ),
        ),
        const SizedBox(width: 16),
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
                      modulePositions: _modulePositions,
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
  final List<Translation2d> modulePositions;

  const _RobotPainter({
    required this.colorScheme,
    required this.bumperWidth,
    required this.bumperLength,
    required this.modulePositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.secondary;

    Offset center = Offset(size.width / 2.0, size.height / 2.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pi / 2);

    canvas.drawCircle(Offset.zero, 1.5, paint);

    double pixelsPerMeter =
        min((size.width - 64) / bumperWidth, (size.height - 64) / bumperLength);

    PathPainterUtil.paintRobotOutlinePixels(
      Offset.zero,
      0.0,
      Size(bumperWidth * pixelsPerMeter, bumperLength * pixelsPerMeter),
      8,
      4.0,
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
