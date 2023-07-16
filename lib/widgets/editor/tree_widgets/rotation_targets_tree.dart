import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';

class RotationTargetsTree extends StatefulWidget {
  const RotationTargetsTree({super.key});

  @override
  State<RotationTargetsTree> createState() => _RotationTargetsTreeState();
}

class _RotationTargetsTreeState extends State<RotationTargetsTree> {
  @override
  Widget build(BuildContext context) {
    return const TreeCardNode(
      title: Text('Rotation Targets'),
      initiallyExpanded: false,
      elevation: 1.0,
      children: [],
    );
  }
}
