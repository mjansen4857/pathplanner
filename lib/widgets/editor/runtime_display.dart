import 'package:flutter/material.dart';

class RuntimeDisplay extends StatelessWidget {
  final num? currentRuntime;
  final num? previousRuntime;

  const RuntimeDisplay({
    super.key,
    required this.currentRuntime,
    required this.previousRuntime,
  });

  @override
  Widget build(BuildContext context) {
    final runtime = currentRuntime ?? 0;
    final prevRuntime = previousRuntime ?? runtime;
    final difference = runtime - prevRuntime;
    final isShortened = difference < 0;
    final isSignificantIncrease = difference > 0.15;
    final isMinorIncrease = difference > 0.05 && !isSignificantIncrease;
    final isNoSignificantChange = difference.abs() <= 0.05;

    return Tooltip(
      message: isShortened
          ? 'Path time decreased by ~${difference.abs().toStringAsFixed(2)}s'
          : isNoSignificantChange
              ? 'Path time changed by less than 0.05s'
              : isMinorIncrease
                  ? 'Path time slightly increased by ~${difference.abs().toStringAsFixed(2)}s'
                  : 'Path time increased by ~${difference.abs().toStringAsFixed(2)}s',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isNoSignificantChange
              ? Colors.grey[100]
              : isShortened
                  ? Colors.green[100]
                  : isMinorIncrease
                      ? Colors.orange[100]
                      : Colors.red[100],
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(
            color: isNoSignificantChange
                ? Colors.grey[300]!
                : isShortened
                    ? Colors.green[200]!
                    : isMinorIncrease
                        ? Colors.orange[200]!
                        : Colors.red[200]!,
            width: 1.0,
          ),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: isNoSignificantChange ? 0.7 : 1.0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 500),
            scale: isNoSignificantChange ? 1.0 : 1.05,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isNoSignificantChange) const SizedBox(width: 4),
                Text(
                  '~${runtime.toStringAsFixed(2)}s',
                  style: TextStyle(
                    fontSize: 14,
                    color: isNoSignificantChange
                        ? Colors.grey[800]
                        : isShortened
                            ? Colors.green[800]
                            : isMinorIncrease
                                ? Colors.orange[800]
                                : Colors.red[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (difference.abs() > 0.05) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${isShortened ? '-' : '+'}${difference.abs().toStringAsFixed(2)}s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isShortened
                          ? Colors.green[700]
                          : isMinorIncrease
                              ? Colors.orange[700]
                              : Colors.red[700],
                    ),
                  ),
                ],
                if (!isNoSignificantChange)
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 500),
                    curve: isShortened
                        ? Curves.easeOut // Slide down
                        : isMinorIncrease
                            ? Curves.easeInOut // Slide right
                            : Curves.bounceOut, // Bounce up
                    offset: isShortened
                        ? const Offset(0, 0.1) // Slide down
                        : isMinorIncrease
                            ? const Offset(0.1, 0) // Slide right
                            : const Offset(0, -0.1), // Bounce up
                    child: Icon(
                      isShortened
                          ? Icons.arrow_downward
                          : isMinorIncrease
                              ? Icons.arrow_forward
                              : Icons.arrow_upward,
                      color: isShortened
                          ? Colors.green[700]
                          : isMinorIncrease
                              ? Colors.orange[700]
                              : Colors.red[700],
                      size: 16.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
