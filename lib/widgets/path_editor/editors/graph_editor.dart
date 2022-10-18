import 'dart:core';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
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
  static String prefShowRotation = 'graphShowRotation';
  static String prefShowAngularVelocity = 'graphShowAngularVelocity';
  static String prefShowCurvature = 'graphShowCurvature';
  static Color colorVelocity = Colors.red;
  static Color colorAccel = Colors.orange;
  static Color colorHeading = Colors.yellow;
  static Color colorRotation = Colors.yellow;
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
  bool _isSampled = false;
  bool _cardMinimized = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 48, 48, 72),
          child: _LineChart(
              isSampled: _isSampled,
              path: widget.path,
              holonomicMode: widget.holonomicMode,
              prefs: widget.prefs),
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
        onShouldRedraw: () {
          setState(() {
            // Force rebuild card to update runtime
          });
        },
        prefs: widget.prefs,
        isSampled: _isSampled,
        cardMinimized: _cardMinimized);
  }

  Widget _buildGeneratorSettingsCard() {
    return GeneratorSettingsCard(
      path: widget.path,
      stackKey: _key,
      onShouldSave: () async {
        await widget.path.generateTrajectory();

        setState(() {
          // Force rebuild card to update runtime
        });

        widget.savePath(widget.path);
      },
      prefs: widget.prefs,
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart(
      {required this.isSampled,
      required this.path,
      required this.holonomicMode,
      required this.prefs});

  final bool isSampled;
  final RobotPath path;
  final bool holonomicMode;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    List<FlSpot> velocity, acceleration, heading, rotation, angular, curvature;
    TrajectoryState? state;
    double min, max, time;
    int idx, length;

    if (isSampled) {
      length = (path.generatedTrajectory.getRuntime() + 0.0199999) ~/ 0.02;
    } else {
      length = path.generatedTrajectory.states.length;
    }

    velocity = [];
    acceleration = [];
    heading = [];
    rotation = [];
    angular = [];
    curvature = [];

    min = -1.0;
    max = 1.0;
    time = 0.0;

    for (idx = 0; idx < length; idx++) {
      if (isSampled) {
        state = path.generatedTrajectory.sample(idx / 50.0);
        time = idx / 50.0;
      } else {
        state = path.generatedTrajectory.states[idx];
        time = state.timeSeconds.toDouble();
      }

      if (prefs.getBool(GraphEditor.prefShowVelocity) ?? true) {
        velocity.add(FlSpot(time, state.velocityMetersPerSecond.toDouble()));
        min = velocity[idx].y < min ? velocity[idx].y : min;
        max = velocity[idx].y > max ? velocity[idx].y : max;
      }

      if (prefs.getBool(GraphEditor.prefShowAccel) ?? true) {
        acceleration
            .add(FlSpot(time, state.accelerationMetersPerSecondSq.toDouble()));
        min = acceleration[idx].y < min ? acceleration[idx].y : min;
        max = acceleration[idx].y > max ? acceleration[idx].y : max;
      }

      if (!holonomicMode) {
        if (prefs.getBool(GraphEditor.prefShowHeading) ?? true) {
          heading.add(FlSpot(time, state.headingRadians.toDouble()));
          min = heading[idx].y < min ? heading[idx].y : min;
          max = heading[idx].y > max ? heading[idx].y : max;
        }

        if (prefs.getBool(GraphEditor.prefShowAngularVelocity) ?? true) {
          angular.add(FlSpot(time, state.angularVelocity.toDouble()));
          min = angular[idx].y < min ? angular[idx].y : min;
          max = angular[idx].y > max ? angular[idx].y : max;
        }

        if (prefs.getBool(GraphEditor.prefShowCurvature) ?? true) {
          curvature.add(FlSpot(time, state.curvatureRadPerMeter.toDouble()));
          min = curvature[idx].y < min ? curvature[idx].y : min;
          max = curvature[idx].y > max ? curvature[idx].y : max;
        }
      } else {
        if (prefs.getBool(GraphEditor.prefShowRotation) ?? true) {
          rotation.add(FlSpot(
              time, (state.holonomicRotation.toDouble() * 3.14159) / 180.0));
          min = rotation[idx].y < min ? rotation[idx].y : min;
          max = rotation[idx].y > max ? rotation[idx].y : max;
        }

        if (prefs.getBool(GraphEditor.prefShowAngularVelocity) ?? true) {
          angular.add(FlSpot(time,
              (state.holonomicAngularVelocity.toDouble() * 3.14159) / 180.0));
          min = angular[idx].y < min ? angular[idx].y : min;
          max = angular[idx].y > max ? angular[idx].y : max;
        }
      }
    }

    List<LineChartBarData> lineBarsData = [];

    if (prefs.getBool(GraphEditor.prefShowVelocity) ?? true) {
      LineChartBarData dataVelocity = LineChartBarData(
        isCurved: false,
        color: GraphEditor.colorVelocity,
        barWidth: 5,
        isStrokeCapRound: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        spots: velocity,
      );

      lineBarsData.add(dataVelocity);
    }

    if (prefs.getBool(GraphEditor.prefShowAccel) ?? true) {
      LineChartBarData dataAcceleration = LineChartBarData(
        isCurved: false,
        color: GraphEditor.colorAccel,
        barWidth: 5,
        isStrokeCapRound: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        spots: acceleration,
      );

      lineBarsData.add(dataAcceleration);
    }

    if (!holonomicMode) {
      if (prefs.getBool(GraphEditor.prefShowHeading) ?? true) {
        LineChartBarData dataHeading = LineChartBarData(
          isCurved: false,
          color: GraphEditor.colorHeading,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          spots: heading,
        );

        lineBarsData.add(dataHeading);
      }

      if (prefs.getBool(GraphEditor.prefShowAngularVelocity) ?? true) {
        LineChartBarData dataAngular = LineChartBarData(
          isCurved: false,
          color: GraphEditor.colorAngularVelocity,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          spots: angular,
        );

        lineBarsData.add(dataAngular);
      }

      if (prefs.getBool(GraphEditor.prefShowCurvature) ?? true) {
        LineChartBarData dataCurvature = LineChartBarData(
          isCurved: false,
          color: GraphEditor.colorCurvature,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          spots: curvature,
        );

        lineBarsData.add(dataCurvature);
      }
    } else {
      if (prefs.getBool(GraphEditor.prefShowRotation) ?? true) {
        LineChartBarData dataHoloRotation = LineChartBarData(
          isCurved: false,
          color: GraphEditor.colorRotation,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          spots: rotation,
        );

        lineBarsData.add(dataHoloRotation);
      }

      if (prefs.getBool(GraphEditor.prefShowAngularVelocity) ?? true) {
        LineChartBarData dataHoloAngle = LineChartBarData(
          isCurved: false,
          color: GraphEditor.colorAngularVelocity,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          spots: angular,
        );

        lineBarsData.add(dataHoloAngle);
      }
    }

    List<VerticalLine> markers = List.empty(growable: true);

    for (idx = 0; idx < path.markers.length; idx++) {
      markers.add(VerticalLine(
          x: path.markers[idx].timeSeconds,
          label: VerticalLineLabel(
              labelResolver: markerLabel,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              alignment: Alignment.topCenter,
              show: true),
          color: Colors.white38,
          strokeWidth: 3));
    }

    ExtraLinesData extraLines = ExtraLinesData(horizontalLines: [
      HorizontalLine(
        y: 0,
        color: Colors.white60,
        strokeWidth: 3,
      ),
    ], verticalLines: markers, extraLinesOnTop: false);

    SideTitles leftTitles = SideTitles(
      getTitlesWidget: leftTitleWidgets,
      showTitles: true,
      reservedSize: 40,
    );

    SideTitles bottomTitles = SideTitles(
      showTitles: true,
      reservedSize: 32,
      getTitlesWidget: bottomTitleWidgets,
    );

    FlTitlesData titlesData = FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: bottomTitles,
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: AxisTitles(
        sideTitles: leftTitles,
      ),
    );

    FlBorderData borderData = FlBorderData(
      show: true,
      border: const Border(
        bottom: BorderSide(color: Colors.white24, width: 4),
        left: BorderSide(color: Colors.white24, width: 4),
        right: BorderSide(color: Colors.white24, width: 4),
        top: BorderSide(color: Colors.white24, width: 4),
      ),
    );

    LineChartData data = LineChartData(
      lineTouchData: LineTouchData(enabled: false),
      gridData: FlGridData(show: true),
      titlesData: titlesData,
      borderData: borderData,
      lineBarsData: lineBarsData,
      extraLinesData: extraLines,
      minX: 0,
      maxX: time,
      minY: min.floorToDouble(),
      maxY: max.ceilToDouble(),
    );

    return LineChart(
      data,
      swapAnimationDuration: const Duration(milliseconds: 0),
    );
  }

  String markerLabel(VerticalLine line) {
    for (int idx = 0; idx < path.markers.length; idx++) {
      if (path.markers[idx].timeSeconds == line.x) {
        return path.markers[idx].name;
      }
    }
    return '';
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    if ((value - value.toInt()).abs() > 0.01) {
      return const Text('');
    }

    const style = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 10,
        child: Text(value.toInt().toString(),
            style: style, textAlign: TextAlign.center));
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    if (((value * 10.0) - (value * 10.0).round().toInt()).abs() > 0.01) {
      return const Text('');
    }

    const style = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: Text(value.toStringAsFixed(1), style: style),
    );
  }
}
