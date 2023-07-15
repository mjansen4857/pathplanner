import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';

class ConstraintZonesTree extends StatefulWidget {
  const ConstraintZonesTree({super.key});

  @override
  State<ConstraintZonesTree> createState() => _ConstraintZonesTreeState();
}

class _ConstraintZonesTreeState extends State<ConstraintZonesTree> {
  @override
  Widget build(BuildContext context) {
    return const TreeCardNode(
      title: Text('Constraint Zones'),
      initiallyExpanded: false,
      elevation: 1.0,
      children: [],
    );
  }
}
