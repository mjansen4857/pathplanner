import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';

class EventMarkersTree extends StatefulWidget {
  const EventMarkersTree({super.key});

  @override
  State<EventMarkersTree> createState() => _EventMarkersTreeState();
}

class _EventMarkersTreeState extends State<EventMarkersTree> {
  @override
  Widget build(BuildContext context) {
    return const TreeCardNode(
      title: Text('Event Markers'),
      initiallyExpanded: false,
      elevation: 1.0,
      children: [],
    );
  }
}
