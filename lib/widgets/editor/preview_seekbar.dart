import 'package:material_ui/material_ui.dart';

class PreviewSeekbar extends StatefulWidget {
  final AnimationController previewController;
  final ValueChanged<bool>? onPauseStateChanged;
  final num totalPathTime;
  final bool enabled;

  const PreviewSeekbar({
    super.key,
    required this.previewController,
    this.onPauseStateChanged,
    required this.totalPathTime,
    this.enabled = true,
  });

  @override
  State<PreviewSeekbar> createState() => _PreviewSeekbarState();
}

class _PreviewSeekbarState extends State<PreviewSeekbar> {
  @override
  void initState() {
    super.initState();
    _resetIfDisabled();
  }

  @override
  void didUpdateWidget(covariant PreviewSeekbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _resetIfDisabled();
    }
  }

  void _resetIfDisabled() {
    if (!widget.enabled) {
      widget.previewController.stop();
      if (widget.previewController.value != 0.0) {
        widget.previewController.value = 0.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Card(
          color: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                IconButton(
                  onPressed: !widget.enabled
                      ? null
                      : () {
                          setState(() {
                            if (widget.previewController.isAnimating) {
                              widget.previewController.stop();
                              widget.onPauseStateChanged?.call(true);
                            } else {
                              widget.previewController.repeat();
                              widget.onPauseStateChanged?.call(false);
                            }
                          });
                        },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: widget.previewController.isAnimating
                        ? const Icon(Icons.pause)
                        : const Icon(Icons.play_arrow),
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: widget.previewController.isAnimating
                      ? 'Pause'
                      : 'Play',
                ),
                IconButton(
                  onPressed: !widget.enabled
                      ? null
                      : () {
                          setState(() {
                            widget.previewController.reset();
                            widget.previewController
                                .repeat(); // Start playing again after reset
                            widget.onPauseStateChanged?.call(false);
                          });
                        },
                  icon: const Icon(Icons.replay),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Restart',
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: widget.previewController.view,
                    builder: (context, _) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          sliderTheme: const SliderThemeData(
                            showValueIndicator: ShowValueIndicator.onDrag,
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                        ),
                        child: Slider(
                          value: widget.previewController.value,
                          label:
                              (widget.previewController.value *
                                      widget.totalPathTime)
                                  .toStringAsFixed(2),
                          onChanged: !widget.enabled
                              ? null
                              : (value) {
                                  if (widget.previewController.isAnimating) {
                                    setState(() {
                                      widget.previewController.stop();
                                    });
                                    widget.onPauseStateChanged?.call(true);
                                  }

                                  widget.previewController.value = value;
                                },
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: AnimatedBuilder(
                    animation: widget.previewController.view,
                    builder: (context, _) => Text(
                      (widget.previewController.value * widget.totalPathTime)
                          .toStringAsFixed(2),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
