import 'package:flutter/material.dart';

class PreviewSeekbar extends StatefulWidget {
  final AnimationController previewController;

  const PreviewSeekbar({
    super.key,
    required this.previewController,
  });

  @override
  State<PreviewSeekbar> createState() => _PreviewSeekbarState();
}

class _PreviewSeekbarState extends State<PreviewSeekbar> {
  RangeValues rangeValues = const RangeValues(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Card(
          elevation: 2.0,
          child: SizedBox(
            height: 80,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          if (widget.previewController.isAnimating) {
                            widget.previewController.stop();
                          } else {
                            widget.previewController.repeat(min: rangeValues.start, max: rangeValues.end);
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
                            return Slider(
                              value: widget.previewController.view.value,
                              focusNode: FocusNode(
                                skipTraversal: true,
                                canRequestFocus: false,
                              ),
                              onChanged: (value) {
                                if (widget.previewController.isAnimating) {
                                  setState(() {
                                    widget.previewController.stop();
                                  });
                                }

                                widget.previewController.value = value;
                              },
                            );
                          }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Row(
                //   children: [
                    Expanded(
                      child: AnimatedBuilder(
                          animation: widget.previewController.view,
                          builder: (context, _) {
                            return RangeSlider(
                              values: rangeValues,
                              labels: RangeLabels(
                                rangeValues.start.toString(),
                                rangeValues.end.toString(),
                              ),
                              onChanged: (RangeValues values) {
                                if (widget.previewController.isAnimating) {
                                  setState(() {
                                    widget.previewController.stop();
                                    rangeValues = values;
                                  });
                                }
                              },
                            );
                          }),
                    ),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
