import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/trajectory_render.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:image/image.dart' as img;

typedef GifProgress = ({double progress, Uint8List? bytes});

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
  double? _renderProgress;
  late ThemeData _theme;

  final List<Uint8List> _gifImagesBytes = [];
  static IsolateManager? _manager;

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
          SizedBox(
            width: 800,
            height: 400,
            child: FittedBox(
              child: WidgetsToImage(
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
            ),
          ),
          const SizedBox(height: 12),
          ConditionalWidget(
            condition: _renderProgress != null,
            trueChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_renderProgress == 0.0
                    ? 'Capturing Frames...'
                    : 'Encoding GIF...'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _renderProgress,
                ),
              ],
            ),
            falseChild: Row(
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
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                  onPressed: () async {
                    if (!_renderGif) {
                      final imageBytes =
                          await _controller.capture(pixelRatio: 1);

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
                        _renderProgress = 0.0;
                      });
                      _gifImagesBytes.clear();
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _renderGifFrame());
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _renderGifFrame([bool finalFrame = false]) async {
    if (!mounted) {
      return;
    }

    final imageBytes = await _controller.capture(pixelRatio: 1);
    _gifImagesBytes.add(imageBytes!);

    if (!mounted) {
      return;
    }

    if (finalFrame) {
      // Save the gif

      _manager ??= IsolateManager.createCustom(_encodeGif);
      final GifProgress result =
          await _manager!.compute(_gifImagesBytes, callback: (progressValue) {
        GifProgress progress = progressValue;
        if (mounted) {
          setState(() {
            _renderProgress = progress.progress;
          });
        }

        return progress.bytes != null;
      });

      if (mounted) {
        setState(() {
          _renderProgress = null;
        });

        if (result.bytes != null) {
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
            await file.writeAsBytes(result.bytes!);
          }
        }
      }
    } else {
      double nextTime = _sampleTime + 0.04;
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

  @isolateManagerCustomWorker
  static void _encodeGif(dynamic params) {
    IsolateManagerFunction.customFunction<GifProgress, List<Uint8List>>(params,
        onEvent: (controller, message) {
      img.PngDecoder decoder = img.PngDecoder();
      img.GifEncoder encoder = img.GifEncoder(
        numColors: 64,
        dither: img.DitherKernel.none,
      );

      for (int i = 0; i < message.length; i++) {
        encoder.addFrame(decoder.decode(message[i])!, duration: 4);
        controller.sendResult((
          progress: (i / (message.length - 1)),
          bytes: null, // Only bother sending the bytes for the final result
        ));
      }

      return (progress: 1.0, bytes: encoder.finish());
    });
  }
}
