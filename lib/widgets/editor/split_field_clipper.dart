import 'package:flutter/widgets.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// Clips the field beneath the side panel without changing its layout or zoom.
class SplitFieldClipper extends CustomClipper<Rect> {
  final MultiSplitViewController controller;
  final bool fieldOnRight;

  SplitFieldClipper({required this.controller, required this.fieldOnRight})
    : super(reclip: controller);

  @override
  Rect getClip(Size size) {
    final divider = MultiSplitViewThemeData().dividerThickness;
    final left = controller.areas[0].flex!;
    final right = controller.areas[1].flex!;
    final split = (size.width - divider) * left / (left + right);
    return fieldOnRight
        ? Rect.fromLTRB(split + divider, 0, size.width, size.height)
        : Rect.fromLTWH(0, 0, split, size.height);
  }

  @override
  bool shouldReclip(SplitFieldClipper oldClipper) =>
      controller != oldClipper.controller ||
      fieldOnRight != oldClipper.fieldOnRight;
}
