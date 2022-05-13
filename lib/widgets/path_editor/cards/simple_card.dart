import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleCard extends StatefulWidget {
  final Widget? child;
  final GlobalKey stackKey;
  final SharedPreferences prefs;

  SimpleCard(
      {required this.stackKey, this.child, required this.prefs, super.key});

  @override
  _SimpleCardState createState() => _SimpleCardState();
}

class _SimpleCardState extends State<SimpleCard> {
  @override
  Widget build(BuildContext context) {
    return DraggableCard(
      stackKey: widget.stackKey,
      defaultPosition: CardPosition(top: 0, right: 0),
      prefsKey: 'simpleCardPos',
      prefs: widget.prefs,
      child: Center(
        child: widget.child,
      ),
    );
  }
}
