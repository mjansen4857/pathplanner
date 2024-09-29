import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelemetryPage extends StatefulWidget {
  final FieldImage fieldImage;
  final PPLibTelemetry telemetry;
  final SharedPreferences prefs;

  const TelemetryPage({
    super.key,
    required this.fieldImage,
    required this.telemetry,
    required this.prefs,
  });

  @override
  State<TelemetryPage> createState() => _TelemetryPageState();
}

class _TelemetryPageState extends State<TelemetryPage> {
  bool _connected = false;
  final List<List<num>> _velData = [];
  final List<num> _inaccuracyData = [];
  List<num>? _currentPath;
  Pose2d? _currentPose;
  Pose2d? _targetPose;
  late final Size _robotSize;

  @override
  void initState() {
    super.initState();

    var width =
        widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth;
    var length =
        widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength;
    _robotSize = Size(width, length);

    widget.telemetry.connectionStatusStream().listen((connected) {
      if (mounted) {
        setState(() {
          _connected = connected;
        });
      }
    });

    widget.telemetry.velocitiesStream().listen((vels) {
      if (mounted) {
        setState(() {
          _velData.add(vels);
          if (_velData.length > 150) {
            _velData.removeAt(0);
          }
        });
      }
    });

    widget.telemetry.inaccuracyStream().listen((inaccuracy) {
      if (mounted) {
        setState(() {
          _inaccuracyData.add(inaccuracy);
          if (_inaccuracyData.length > 150) {
            _inaccuracyData.removeAt(0);
          }
        });
      }
    });

    widget.telemetry.currentPoseStream().listen((pose) {
      if (mounted) {
        setState(() {
          if (pose == null) {
            _currentPose = null;
          } else {
            _currentPose = Pose2d(
              Translation2d(pose[0], pose[1]),
              Rotation2d(pose[2]),
            );
          }
        });
      }
    });

    widget.telemetry.targetPoseStream().listen((pose) {
      if (mounted) {
        setState(() {
          if (pose == null) {
            _targetPose = null;
          } else {
            _targetPose = Pose2d(
              Translation2d(pose[0], pose[1]),
              Rotation2d(pose[2]),
            );
          }
        });
      }
    });

    widget.telemetry.currentPathStream().listen((path) {
      if (mounted) {
        setState(() {
          _currentPath = path;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_connected) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Attempting to connect to robot...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 7,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InteractiveViewer(
                clipBehavior: Clip.none,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      widget.fieldImage.getWidget(),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: TelemetryPainter(
                            fieldImage: widget.fieldImage,
                            robotSize: _robotSize,
                            currentPose: _currentPose,
                            targetPose: _targetPose,
                            currentPath: _currentPath,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate().fade(duration: 300.ms, curve: Curves.easeInOut),
        Expanded(
          flex: 4,
          child: Row(
            children: [
              _buildGraph(
                title: 'Robot Velocity',
                legend: _buildLegend(Colors.green, Colors.deepPurple),
                data: _buildData(
                  maxY: 6.0,
                  horizontalInterval: 1.5,
                  spots: [
                    [
                      for (int i = 0; i < _velData.length; i++)
                        FlSpot(i * 0.033, _velData[i][1].toDouble()),
                    ],
                    [
                      for (int i = 0; i < _velData.length; i++)
                        FlSpot(i * 0.033, _velData[i][0].toDouble()),
                    ],
                  ],
                  lineGradients: const [
                    LinearGradient(
                      colors: [
                        Colors.deepPurple,
                        Colors.deepPurpleAccent,
                      ],
                    ),
                    LinearGradient(
                      colors: [
                        Colors.green,
                        Colors.greenAccent,
                      ],
                    ),
                  ],
                ),
              ),
              _buildGraph(
                title: 'Angular Velocity',
                legend: _buildLegend(Colors.orange, Colors.blue),
                data: _buildData(
                  minY: -2 * pi,
                  maxY: 2 * pi,
                  horizontalInterval: pi,
                  spots: [
                    [
                      for (int i = 0; i < _velData.length; i++)
                        FlSpot(i * 0.033, _velData[i][3].toDouble()),
                    ],
                    [
                      for (int i = 0; i < _velData.length; i++)
                        FlSpot(i * 0.033, _velData[i][2].toDouble()),
                    ],
                  ],
                  lineGradients: const [
                    LinearGradient(
                      colors: [
                        Colors.blue,
                        Colors.blueAccent,
                      ],
                    ),
                    LinearGradient(
                      colors: [
                        Colors.orange,
                        Colors.orangeAccent,
                      ],
                    ),
                  ],
                ),
              ),
              _buildGraph(
                title: 'Path Inaccuracy',
                data: _buildData(
                  maxY: 1.0,
                  horizontalInterval: 0.25,
                  spots: [
                    [
                      for (int i = 0; i < _inaccuracyData.length; i++)
                        FlSpot(i * 0.033, _inaccuracyData[i].toDouble()),
                    ],
                  ],
                  lineGradients: const [
                    LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.redAccent,
                      ],
                    ),
                  ],
                ),
              ),
            ]
                .animate(interval: 100.ms)
                .fade(duration: 300.ms, curve: Curves.easeInOut)
                .slide(begin: const Offset(0, 0.3)),
          ),
        ),
      ],
    );
  }

  Widget _buildGraph({
    required String title,
    required LineChartData data,
    Widget? legend,
  }) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
        child: Stack(
          children: [
            Center(
              child: LineChart(
                data,
                duration: const Duration(milliseconds: 0),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            if (legend != null)
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: legend,
                ),
              ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildData({
    required List<List<FlSpot>> spots,
    required List<LinearGradient> lineGradients,
    required double maxY,
    double minY = 0,
    double? horizontalInterval,
  }) {
    assert(spots.length == lineGradients.length);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        verticalInterval: 1,
        horizontalInterval: horizontalInterval,
      ),
      lineTouchData: const LineTouchData(enabled: false),
      titlesData: const FlTitlesData(
        show: false,
      ),
      borderData: FlBorderData(
        show: false,
      ),
      minX: 0,
      maxX: 5,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        for (int i = 0; i < spots.length; i++)
          LineChartBarData(
            spots: spots[i],
            shadow: const Shadow(offset: Offset(0, 5), blurRadius: 5),
            isCurved: true,
            gradient: lineGradients[i],
            barWidth: 5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
      ],
    );
  }

  Widget _buildLegend(Color actualColor, Color commandedColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: actualColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Actual'),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: commandedColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Commanded'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TelemetryPainter extends CustomPainter {
  final FieldImage fieldImage;
  final Size robotSize;
  final Pose2d? currentPose;
  final Pose2d? targetPose;
  final List<num>? currentPath;

  static double scale = 1;

  const TelemetryPainter({
    required this.fieldImage,
    required this.robotSize,
    this.currentPose,
    this.targetPose,
    this.currentPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    if (currentPath != null) {
      Paint p = Paint()
        ..color = Colors.grey[700]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      Path path = Path();
      for (int i = 0; i < currentPath!.length - 3; i += 3) {
        Offset offset = PathPainterUtil.pointToPixelOffset(
            Translation2d(currentPath![i], currentPath![i + 1]),
            scale,
            fieldImage);
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }

      canvas.drawPath(path, p);
    }

    if (targetPose != null) {
      PathPainterUtil.paintRobotOutline(targetPose!, fieldImage, robotSize,
          scale, canvas, Colors.grey[600]!.withOpacity(0.75));
    }

    if (currentPose != null) {
      PathPainterUtil.paintRobotOutline(currentPose!, fieldImage, robotSize,
          scale, canvas, Colors.grey[400]!);
    }
  }

  @override
  bool shouldRepaint(TelemetryPainter oldDelegate) {
    return oldDelegate.fieldImage != fieldImage ||
        oldDelegate.robotSize != robotSize ||
        oldDelegate.currentPose != currentPose ||
        oldDelegate.targetPose != targetPose ||
        !listEquals(oldDelegate.currentPath, oldDelegate.currentPath);
  }
}
