import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/trajectory_render.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:image/image.dart' as img;

class TrajectoryRenderDialog extends StatefulWidget {
  final FieldImage fieldImage;
  final SharedPreferences prefs;
  final PathPlannerTrajectory trajectory;

  const TrajectoryRenderDialog({
    super.key,
    required this.fieldImage,
    required this.prefs,
    required this.trajectory,
  });

  @override
  State<TrajectoryRenderDialog> createState() => _TrajectoryRenderDialogState();
}

class _TrajectoryRenderDialogState extends State<TrajectoryRenderDialog> {
  late Color _teamColor;
  final WidgetsToImageController _controller = WidgetsToImageController();

  double _sampleTime = 0.0;
  bool _darkMode = true;
  bool _solidBackground = true;
  bool _renderGif = false;
  late ThemeData _theme;

  img.GifEncoder _gifEncoder = img.GifEncoder(dither: img.DitherKernel.none);

  @override
  void initState() {
    super.initState();

    _teamColor =
        Color(widget.prefs.getInt(PrefsKeys.teamColor) ?? Defaults.teamColor);

    _theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: _teamColor,
      brightness: _darkMode ? Brightness.dark : Brightness.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WidgetsToImage(
            controller: _controller,
            child: Container(
              color: _solidBackground
                  ? (_darkMode ? _theme.colorScheme.surface : Colors.white)
                  : null,
              child: Theme(
                data: _theme,
                child: TrajectoryRender(
                  fieldImage: widget.fieldImage,
                  prefs: widget.prefs,
                  trajectory: widget.trajectory,
                  sampleTime: _renderGif ? _sampleTime : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Light'),
                  ),
                ],
                selected: {_darkMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _darkMode = selection.first;
                    _theme = ThemeData(
                      useMaterial3: true,
                      colorSchemeSeed: _teamColor,
                      brightness:
                          _darkMode ? Brightness.dark : Brightness.light,
                    );
                  });
                },
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Solid'),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Transparent'),
                  ),
                ],
                selected: {_solidBackground},
                onSelectionChanged: _renderGif
                    ? null
                    : (selection) {
                        setState(() {
                          _solidBackground = selection.first;
                        });
                      },
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('PNG'),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('GIF'),
                  ),
                ],
                selected: {_renderGif},
                onSelectionChanged: (selection) {
                  setState(() {
                    _renderGif = selection.first;
                    if (_renderGif) {
                      _solidBackground = true;
                      _sampleTime = 0.0;
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Render'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                ),
                onPressed: () async {
                  if (!_renderGif) {
                    final imageBytes = await _controller.capture(pixelRatio: 1);

                    if (imageBytes != null) {
                      final saveLocation = await getSaveLocation(
                        acceptedTypeGroups: [
                          const XTypeGroup(
                            label: 'PNG',
                            extensions: [
                              'png',
                            ],
                          )
                        ],
                        suggestedName: 'pathplanner.png',
                      );

                      if (saveLocation != null) {
                        final file = File(saveLocation.path);
                        await file.writeAsBytes(imageBytes);
                      }
                    }
                  } else {
                    setState(() {
                      _sampleTime = 0.0;
                    });
                    _gifEncoder = img.GifEncoder(
                        dither: img.DitherKernel.none,
                        numColors: 64,
                        samplingFactor: 10);
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _renderGifFrame());
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _renderGifFrame([bool finalFrame = false]) async {
    final imageBytes = await _controller.capture(pixelRatio: 1);

    if (imageBytes != null) {
      _gifEncoder.addFrame(img.PngDecoder().decode(imageBytes)!, duration: 5);
    }

    if (finalFrame) {
      // Save the gif
      final saveLocation = await getSaveLocation(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'GIF',
            extensions: [
              'gif',
            ],
          )
        ],
        suggestedName: 'pathplanner.gif',
      );

      if (saveLocation != null) {
        final file = File(saveLocation.path);
        await file.writeAsBytes(_gifEncoder.finish()!);
      }
    } else {
      double nextTime = _sampleTime + 0.05;
      if (nextTime >= widget.trajectory.getTotalTimeSeconds()) {
        setState(() {
          _sampleTime = widget.trajectory.getTotalTimeSeconds().toDouble();
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _renderGifFrame(true));
      } else {
        setState(() {
          _sampleTime = nextTime;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _renderGifFrame());
      }
    }
  }
}
