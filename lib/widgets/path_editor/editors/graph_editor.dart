import 'dart:core';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/services/generator/geometry_util.dart';
import 'package:pathplanner/services/generator/trajectory.dart';
import 'package:pathplanner/widgets/path_editor/cards/generator_settings_card.dart';
import 'package:pathplanner/widgets/path_editor/cards/graph_settings_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GraphEditor extends StatefulWidget {
  final RobotPath path;
  final bool holonomicMode;
  final void Function(RobotPath path) savePath;
  final SharedPreferences prefs;
  static String prefShowVelocity = 'graphShowVelocity';
  static String prefShowAccel = 'graphShowAccel';
  static String prefShowHeading = 'graphShowHeading';
  static String prefShowAngularVelocity = 'graphShowAngularVelocity';
  static String prefShowCurvature = 'graphShowCurvature';
  static Color colorVelocity = Colors.red;
  static Color colorAccel = Colors.orange;
  static Color colorHeading = Colors.yellow;
  static Color colorAngularVelocity = Colors.green;
  static Color colorCurvature = Colors.blue;

  const GraphEditor(
      {required this.path,
      required this.holonomicMode,
      required this.savePath,
      required this.prefs,
      super.key});

  @override
  State<GraphEditor> createState() => _GraphEditorState();
}

class _GraphEditorState extends State<GraphEditor> {
  final GlobalKey _key = GlobalKey();
  bool _isSampled = true;
  bool _cardMinimized = false;

  List<FlSpot> _sampledVel = [];
  List<FlSpot> _sampledAccel = [];
  List<FlSpot> _sampledHeading = [];
  List<FlSpot> _sampledRotation = [];
  List<FlSpot> _sampledAngularVel = [];
  List<FlSpot> _sampledHoloAngularVel = [];
  List<FlSpot> _sampledCurvature = [];

  List<FlSpot> _fullVel = [];
  List<FlSpot> _fullAccel = [];
  List<FlSpot> _fullHeading = [];
  List<FlSpot> _fullRotation = [];
  List<FlSpot> _fullAngularVel = [];
  List<FlSpot> _fullHoloAngularVel = [];
  List<FlSpot> _fullCurvature = [];

  late bool _showVelocity;
  late bool _showAccel;
  late bool _showHeading;
  late bool _showAngularVel;
  late bool _showCurvature;

  @override
  void initState() {
    super.initState();

    _fillData();

    _showVelocity = widget.prefs.getBool(GraphEditor.prefShowVelocity) ?? true;
    _showAccel = widget.prefs.getBool(GraphEditor.prefShowAccel) ?? true;
    _showHeading = widget.prefs.getBool(GraphEditor.prefShowHeading) ?? true;
    _showAngularVel =
        widget.prefs.getBool(GraphEditor.prefShowAngularVelocity) ?? true;
    _showCurvature =
        widget.prefs.getBool(GraphEditor.prefShowCurvature) ?? true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fillData();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 48, 48, 72),
          child: _buildChart(),
        ),
        _buildGraphSettingsCard(),
        _buildGeneratorSettingsCard(),
      ],
    );
  }

  Widget _buildGraphSettingsCard() {
    return GraphSettingsCard(
        stackKey: _key,
        holonomicMode: widget.holonomicMode,
        onToggleSampled: () {
          setState(() {
            _isSampled = !_isSampled;
          });
        },
        onToggleMinimized: () {
          setState(() {
            _cardMinimized = !_cardMinimized;
          });
        },
        onSettingChanged: () {
          setState(() {
            _showVelocity =
                widget.prefs.getBool(GraphEditor.prefShowVelocity) ?? true;
            _showAccel =
                widget.prefs.getBool(GraphEditor.prefShowAccel) ?? true;
            _showHeading =
                widget.prefs.getBool(GraphEditor.prefShowHeading) ?? true;
            _showAngularVel =
                widget.prefs.getBool(GraphEditor.prefShowAngularVelocity) ??
                    true;
            _showCurvature =
                widget.prefs.getBool(GraphEditor.prefShowCurvature) ?? true;
          });
        },
        prefs: widget.prefs,
        isSampled: _isSampled,
        cardMinimized: _cardMinimized);
  }

  Widget _buildGeneratorSettingsCard() {
    return GeneratorSettingsCard(
      path: widget.path,
      holonomicMode: widget.holonomicMode,
      stackKey: _key,
      onShouldSave: () async {
        await widget.path.generateTrajectory();

        setState(() {
          _fillData();
        });

        widget.savePath(widget.path);
      },
      prefs: widget.prefs,
    );
  }

  void _fillData() {
    Trajectory traj = widget.path.generatedTrajectory;

    // Create sampled data
    _sampledVel = [];
    _sampledAccel = [];
    _sampledHeading = [];
    _sampledRotation = [];
    _sampledAngularVel = [];
    _sampledHoloAngularVel = [];
    _sampledCurvature = [];
    for (double t = 0; t <= traj.getRuntime(); t += 0.02) {
      TrajectoryState s = traj.sample(t);

      _sampledVel.add(FlSpot(t, s.velocityMetersPerSecond.toDouble()));
      _sampledAccel.add(FlSpot(t, s.accelerationMetersPerSecondSq.toDouble()));
      _sampledHeading.add(FlSpot(t, s.headingRadians.toDouble()));
      _sampledRotation.add(
          FlSpot(t, GeometryUtil.toRadians(s.holonomicRotation).toDouble()));
      _sampledAngularVel.add(FlSpot(t, s.angularVelocity.toDouble()));
      _sampledHoloAngularVel.add(FlSpot(
          t, GeometryUtil.toRadians(s.holonomicAngularVelocity).toDouble()));
      _sampledCurvature.add(FlSpot(t, s.curvatureRadPerMeter.toDouble()));
    }

    // Create full data
    _fullVel = [];
    _fullAccel = [];
    _fullHeading = [];
    _fullRotation = [];
    _fullAngularVel = [];
    _fullHoloAngularVel = [];
    _fullCurvature = [];
    for (int i = 0; i < traj.states.length; i++) {
      TrajectoryState s = traj.states[i];
      double t = s.timeSeconds.toDouble();

      double vel = s.velocityMetersPerSecond.toDouble();
      double accel = s.accelerationMetersPerSecondSq.toDouble();

      _fullVel.add(FlSpot(t, vel));
      _fullAccel.add(FlSpot(t, accel));
      _fullHeading.add(FlSpot(t, s.headingRadians.toDouble()));
      _fullRotation.add(
          FlSpot(t, GeometryUtil.toRadians(s.holonomicRotation).toDouble()));
      _fullAngularVel.add(FlSpot(t, s.angularVelocity.toDouble()));
      _fullHoloAngularVel.add(FlSpot(
          t, GeometryUtil.toRadians(s.holonomicAngularVelocity).toDouble()));
      _fullCurvature.add(FlSpot(t, s.curvatureRadPerMeter.toDouble()));
    }
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(enabled: false),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Colors.white24, width: 4),
            left: BorderSide(color: Colors.white24, width: 4),
            right: BorderSide(color: Colors.white24, width: 4),
            top: BorderSide(color: Colors.white24, width: 4),
          ),
        ),
        lineBarsData: [
          if (_showVelocity)
            LineChartBarData(
              isCurved: false,
              color: GraphEditor.colorVelocity,
              barWidth: 5,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              spots: _isSampled ? _sampledVel : _fullVel,
            ),
          if (_showAccel)
            LineChartBarData(
              isCurved: false,
              color: GraphEditor.colorAccel,
              barWidth: 5,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              spots: _isSampled ? _sampledAccel : _fullAccel,
            ),
          if (_showHeading)
            LineChartBarData(
              isCurved: false,
              color: GraphEditor.colorHeading,
              barWidth: 5,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              spots: widget.holonomicMode
                  ? (_isSampled ? _sampledRotation : _fullRotation)
                  : (_isSampled ? _sampledHeading : _fullHeading),
            ),
          if (_showAngularVel)
            LineChartBarData(
              isCurved: false,
              color: GraphEditor.colorAngularVelocity,
              barWidth: 5,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              spots: widget.holonomicMode
                  ? (_isSampled ? _sampledHoloAngularVel : _fullHoloAngularVel)
                  : (_isSampled ? _sampledAngularVel : _fullAngularVel),
            ),
          if (_showCurvature)
            LineChartBarData(
              isCurved: false,
              color: GraphEditor.colorCurvature,
              barWidth: 5,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              spots: _isSampled ? _sampledCurvature : _fullCurvature,
            ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: Colors.white60,
              strokeWidth: 3,
            ),
          ],
          verticalLines: [
            for (EventMarker m in widget.path.markers)
              VerticalLine(
                x: m.timeSeconds,
                label: VerticalLineLabel(
                  labelResolver: (_) => m.names[0],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  alignment: Alignment.topCenter,
                  show: true,
                ),
                color: Colors.grey[600],
                strokeWidth: 3,
              ),
          ],
          extraLinesOnTop: true,
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 0.5,
              getTitlesWidget: (value, meta) =>
                  Text(((value * 100).roundToDouble() / 100).toString()),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (value, meta) =>
                  Text(((value * 100).roundToDouble() / 100).toString()),
            ),
          ),
        ),
      ),
      swapAnimationDuration: const Duration(milliseconds: 0),
    );
  }
}
