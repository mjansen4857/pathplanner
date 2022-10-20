import 'package:flutter/material.dart';

class ConditionalWidget extends StatelessWidget {
  final bool condition;
  final Widget trueChild;
  final Widget falseChild;

  const ConditionalWidget(
      {required this.condition,
      required this.trueChild,
      required this.falseChild,
      super.key});

  @override
  Widget build(BuildContext context) {
    if (condition) {
      return trueChild;
    } else {
      return falseChild;
    }
  }
}
