import 'package:flutter/material.dart';

class ProjectItemRoute<T> extends MaterialPageRoute<T> {
  ProjectItemRoute({
    required super.builder,
    super.settings,
  });

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return ScaleTransition(
      scale: animation,
      child: child,
    );
  }
}
