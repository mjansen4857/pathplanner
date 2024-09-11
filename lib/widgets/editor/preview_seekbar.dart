import 'package:flutter/material.dart';

class PreviewSeekbar extends StatefulWidget {
  final AnimationController previewController;
  final ValueChanged<bool>? onPauseStateChanged;
  final num totalPathTime;

  const PreviewSeekbar({
    super.key,
    required this.previewController,
    this.onPauseStateChanged,
    required this.totalPathTime,
  });

  @override
  State<PreviewSeekbar> createState() => _PreviewSeekbarState();
}

class _PreviewSeekbarState extends State<PreviewSeekbar> {
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
          elevation: 2.0,
          child: SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
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
                  icon: widget.previewController.isAnimating
                      ? const Icon(Icons.pause)
                      : const Icon(Icons.play_arrow),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: AnimatedBuilder(
                      animation: widget.previewController.view,
                      builder: (context, _) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            sliderTheme: const SliderThemeData(
                              showValueIndicator: ShowValueIndicator.always,
                            ),
                          ),
                          child: Slider(
                            value: widget.previewController.view.value,
                            label: (widget.previewController.view.value *
                                    widget.totalPathTime)
                                .toStringAsFixed(2),
                            focusNode: FocusNode(
                              skipTraversal: true,
                              canRequestFocus: false,
                            ),
                            onChanged: (value) {
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
                      }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
