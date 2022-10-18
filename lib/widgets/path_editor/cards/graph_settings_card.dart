import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:pathplanner/widgets/path_editor/editors/graph_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GraphSettingsCard extends StatefulWidget {
  final bool holonomicMode;
  final VoidCallback onToggleSampled;
  final VoidCallback onToggleMinimized;
  final VoidCallback onShouldRedraw;
  final GlobalKey stackKey;
  final SharedPreferences prefs;
  final bool isSampled;
  final bool cardMinimized;

  const GraphSettingsCard(
      {required this.stackKey,
      required this.holonomicMode,
      required this.onToggleSampled,
      required this.onToggleMinimized,
      required this.onShouldRedraw,
      required this.prefs,
      required this.isSampled,
      required this.cardMinimized,
      super.key});

  @override
  State<GraphSettingsCard> createState() => _GraphSettingsCardState();
}

class _GraphSettingsCardState extends State<GraphSettingsCard> {
  late bool _showVelocity;
  late bool _showAccel;
  late bool _showHeading;
  late bool _showAngularVelocity;
  late bool _showCurvature;
  late bool _showRotation;

  @override
  void initState() {
    super.initState();

    _showVelocity = widget.prefs.getBool(GraphEditor.prefShowVelocity) ?? true;
    _showAccel = widget.prefs.getBool(GraphEditor.prefShowAccel) ?? true;
    _showHeading = widget.prefs.getBool(GraphEditor.prefShowHeading) ?? true;
    _showAngularVelocity = widget.prefs.getBool(GraphEditor.prefShowAngularVelocity) ?? true;
    _showCurvature = widget.prefs.getBool(GraphEditor.prefShowCurvature) ?? true;
    _showRotation = widget.prefs.getBool(GraphEditor.prefShowRotation) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableCard(
      stackKey: widget.stackKey,
      defaultPosition: const CardPosition(top: 0, right: 0),
      prefsKey: 'graphCardPos',
      prefs: widget.prefs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          // Override gesture detector on UI elements so they won't cause the card to move
          GestureDetector(
            onPanStart: (details) {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Visibility(
                    visible: !widget.cardMinimized,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _buildVelocityAccelRow(context))),
                Visibility(
                    visible: !widget.holonomicMode && !widget.cardMinimized,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _buildHeadingAngularRow(context))),
                Visibility(
                    visible: !widget.holonomicMode && !widget.cardMinimized,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _buildCurvatureRow(context))),
                Visibility(
                    visible: widget.holonomicMode && !widget.cardMinimized,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _buildHolonomicRow(context))),
                const SizedBox(height: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          height: 30,
          width: 30,
          // Override gesture detector on UI elements so they wont cause the card to move
          child: GestureDetector(
            onPanStart: (details) {},
            child: IconButton(
              color: colorScheme.onSurface,
              tooltip: !widget.isSampled
                  ? 'Switch to\nSampled Path'
                  : 'Switch to\nPath States',
              icon: Icon(
                widget.isSampled ? Icons.bar_chart : Icons.stacked_line_chart,
              ),
              onPressed: widget.onToggleSampled,
              splashRadius: 20,
              iconSize: 20,
              padding: const EdgeInsets.all(0),
            ),
          ),
        ),
        Text(
          'Graph Settings',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        SizedBox(
          height: 30,
          width: 30,
          // Override gesture detector on UI elements so they wont cause the card to move
          child: GestureDetector(
            onPanStart: (details) {},
            child: IconButton(
              color: colorScheme.onSurface,
              tooltip: !widget.cardMinimized ? 'Minimize' : 'Show',
              icon: Icon(
                widget.cardMinimized ? Icons.dehaze : Icons.minimize,
              ),
              onPressed: widget.onToggleMinimized,
              splashRadius: 20,
              iconSize: 20,
              padding: const EdgeInsets.all(0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVelocityAccelRow(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Checkbox(
          value: _showVelocity,
          activeColor: GraphEditor.colorVelocity,
          checkColor: GraphEditor.colorVelocity,
          side: BorderSide(color: GraphEditor.colorVelocity, width: 2),
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowVelocity, val!);
            setState(() {
              _showVelocity = val;
            });
            widget.onShouldRedraw();
          },
        ),
        Text(
          'Velocity',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        const SizedBox(width: 12),
        Checkbox(
          value: _showAccel,
          activeColor: GraphEditor.colorAccel,
          checkColor: GraphEditor.colorAccel,
          side: BorderSide(color: GraphEditor.colorAccel, width: 2),
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowAccel, val!);
            setState(() {
              _showAccel = val;
            });
            widget.onShouldRedraw();
          },
        ),
        Text(
          'Acceleration',
          style: TextStyle(color: colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildHeadingAngularRow(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Checkbox(
          value: _showHeading,
          activeColor: GraphEditor.colorHeading,
          checkColor: GraphEditor.colorHeading,
          side: BorderSide(color: GraphEditor.colorHeading, width: 2),
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowHeading, val!);
            setState(() {
              _showHeading = val;
            });
            widget.onShouldRedraw();
          },
        ),
        Text(
          'Heading',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        const SizedBox(width: 12),
        Checkbox(
          value: _showAngularVelocity,
          activeColor: GraphEditor.colorAngularVelocity,
          checkColor: GraphEditor.colorAngularVelocity,
          side: BorderSide(color: GraphEditor.colorAngularVelocity, width: 2),
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowAngularVelocity, val!);
            setState(() {
              _showAngularVelocity = val;
            });
            widget.onShouldRedraw();
          },
        ),
        Text(
          'Angular',
          style: TextStyle(color: colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildCurvatureRow(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Checkbox(
          value: _showCurvature,
          activeColor: GraphEditor.colorCurvature,
          checkColor: GraphEditor.colorCurvature,
          side: BorderSide(color: GraphEditor.colorCurvature, width: 2),
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowCurvature, val!);
            setState(() {
              _showCurvature = val;
              widget.onShouldRedraw();
            });
          },
        ),
        Text(
          'Curvature',
          style: TextStyle(color: colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildHolonomicRow(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Checkbox(
          value: _showRotation,
          activeColor: GraphEditor.colorRotation,
          checkColor: GraphEditor.colorRotation,
          side: BorderSide(color: GraphEditor.colorRotation, width: 2),
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowRotation, val!);
            setState(() {
              _showRotation = val;
            });
            widget.onShouldRedraw();
          },
        ),
        Text(
          'Rotaion',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        const SizedBox(width: 12),
        Checkbox(
          value: _showAngularVelocity,
          activeColor: GraphEditor.colorAngularVelocity,
          checkColor: GraphEditor.colorAngularVelocity,
          side: BorderSide(color: GraphEditor.colorAngularVelocity, width: 2),
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowAngularVelocity, val!);
            setState(() {
              _showAngularVelocity = val;
            });
            widget.onShouldRedraw();
          },
        ),
        Text(
          'Angular',
          style: TextStyle(color: colorScheme.onSurface),
        ),
      ],
    );
  }
}
