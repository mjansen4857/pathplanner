import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/draggable_card.dart';
import 'package:pathplanner/widgets/path_editor/editors/graph_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GraphSettingsCard extends StatefulWidget {
  final bool holonomicMode;
  final VoidCallback onToggleSampled;
  final VoidCallback onToggleMinimized;
  final VoidCallback onSettingChanged;
  final GlobalKey stackKey;
  final SharedPreferences prefs;
  final bool isSampled;
  final bool cardMinimized;

  const GraphSettingsCard(
      {required this.stackKey,
      required this.holonomicMode,
      required this.onToggleSampled,
      required this.onToggleMinimized,
      required this.onSettingChanged,
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

  @override
  void initState() {
    super.initState();

    _showVelocity = widget.prefs.getBool(GraphEditor.prefShowVelocity) ?? true;
    _showAccel = widget.prefs.getBool(GraphEditor.prefShowAccel) ?? true;
    _showHeading = widget.prefs.getBool(GraphEditor.prefShowHeading) ?? true;
    _showAngularVelocity =
        widget.prefs.getBool(GraphEditor.prefShowAngularVelocity) ?? true;
    _showCurvature =
        widget.prefs.getBool(GraphEditor.prefShowCurvature) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableCard(
      stackKey: widget.stackKey,
      defaultPosition: const CardPosition(top: 0, right: 0),
      prefsKey: 'graphCardPos',
      prefs: widget.prefs,
      // Override gesture detector on UI elements so they wont cause the card to move
      child: GestureDetector(
        onPanStart: (details) {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildBody(),
          ],
        ),
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
        Text(
          'Graph Settings',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        SizedBox(
          height: 30,
          width: 30,
          child: IconButton(
            color: colorScheme.onSurface,
            tooltip: !widget.cardMinimized ? 'Minimize' : 'Show',
            icon: Icon(
              widget.cardMinimized ? Icons.expand_more : Icons.expand_less,
            ),
            onPressed: widget.onToggleMinimized,
            splashRadius: 20,
            iconSize: 20,
            padding: const EdgeInsets.all(0),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Visibility(
      visible: !widget.cardMinimized,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeftColumn(),
            _buildRightColumn(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendCheckbox(
          label: 'Velocity',
          value: _showVelocity,
          color: GraphEditor.colorVelocity,
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowVelocity, val!);
            setState(() {
              _showVelocity = val;
            });
            widget.onSettingChanged();
          },
        ),
        _buildLegendCheckbox(
          label: widget.holonomicMode ? 'Rotation' : 'Heading',
          value: _showHeading,
          color: GraphEditor.colorHeading,
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowHeading, val!);
            setState(() {
              _showHeading = val;
            });
            widget.onSettingChanged();
          },
        ),
        _buildLegendCheckbox(
          label: 'Curvature',
          value: _showCurvature,
          color: GraphEditor.colorCurvature,
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowCurvature, val!);
            setState(() {
              _showCurvature = val;
            });
            widget.onSettingChanged();
          },
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendCheckbox(
          label: 'Acceleration',
          value: _showAccel,
          color: GraphEditor.colorAccel,
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowAccel, val!);
            setState(() {
              _showAccel = val;
            });
            widget.onSettingChanged();
          },
        ),
        _buildLegendCheckbox(
          label: 'Angular Vel',
          value: _showAngularVelocity,
          color: GraphEditor.colorAngularVelocity,
          onChanged: (val) {
            widget.prefs.setBool(GraphEditor.prefShowAngularVelocity, val!);
            setState(() {
              _showAngularVelocity = val;
            });
            widget.onSettingChanged();
          },
        ),
      ],
    );
  }

  Widget _buildLegendCheckbox({
    required String label,
    required bool value,
    required Color color,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          activeColor: color,
          checkColor: color,
          side: BorderSide(color: color, width: 2),
          onChanged: onChanged,
        ),
        Text(label),
      ],
    );
  }
}
