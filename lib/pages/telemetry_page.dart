import 'dart:collection';
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
  final Queue<num> _xyErrorData = Queue();
  final Queue<num> _thetaErrorData = Queue();
  List<Pose2d>? _currentPath;
  Pose2d? _currentPose;
  Pose2d? _targetPose;
  late final Size _robotSize;

  bool _gotCurrentPose = false;
  bool _gotTargetPose = false;

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

    widget.telemetry.currentPoseStream().listen((pose) {
      if (mounted) {
        setState(() {
          _currentPose = pose;
          _gotCurrentPose = _currentPose != null;
        });
        _calcError();
      }
    });

    widget.telemetry.targetPoseStream().listen((pose) {
      if (mounted) {
        setState(() {
          _targetPose = pose;
          _gotTargetPose = _targetPose != null;
        });
        _calcError();
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

  void _calcError() {
    if (_gotCurrentPose && _gotTargetPose) {
      setState(() {
        num xyError =
            _currentPose!.translation.getDistance(_targetPose!.translation);
        num thetaError =
            (_currentPose!.rotation - _targetPose!.rotation).radians;

        _xyErrorData.add(xyError);
        if (_xyErrorData.length > 150) {
          _xyErrorData.removeFirst();
        }

        _thetaErrorData.add(thetaError.abs());
        if (_thetaErrorData.length > 150) {
          _thetaErrorData.removeFirst();
        }

        _gotCurrentPose = false;
        _gotTargetPose = false;
      });
    }
  }

  Widget _buildConnectionTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_connected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator()
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: 1.5.seconds, curve: Curves.easeInOut),
            const SizedBox(height: 24),
            const Text(
              'Attempting to connect to robot...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              'Please ensure that:',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _buildConnectionTip('The robot is powered on'),
            _buildConnectionTip('You are connected to the correct network'),
            _buildConnectionTip('The robot code is running'),
            const SizedBox(height: 16),
            Text(
              'Current Server Address: ${widget.telemetry.getServerAddress()}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
          ],
        ).animate().fadeIn(duration: 500.ms, curve: Curves.easeInOut),
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
                            colorScheme: Theme.of(context).colorScheme,
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
                title: 'Path Following Error',
                legend: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendItem('XY Error', Colors.red),
                      const SizedBox(width: 8),
                      _buildLegendItem('Theta Error', Colors.cyan),
                    ],
                  ),
                ),
                data: _buildData(
                  maxY: 1.0,
                  horizontalInterval: 0.25,
                  spots: [
                    [
                      for (int i = 0; i < _xyErrorData.length; i++)
                        FlSpot(i * 0.033, _xyErrorData.elementAt(i).toDouble()),
                    ],
                    [
                      for (int i = 0; i < _thetaErrorData.length; i++)
                        FlSpot(
                            i * 0.033, _thetaErrorData.elementAt(i).toDouble()),
                    ],
                  ],
                  lineGradients: const [
                    LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.redAccent,
                      ],
                    ),
                    LinearGradient(
                      colors: [
                        Colors.cyan,
                        Colors.cyanAccent,
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
            Positioned(
              top: 10,
              left: 12,
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (legend != null)
              Positioned(
                top: 8,
                right: 8,
                child: legend,
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
    double curveSmoothness = 0.35,
  }) {
    assert(spots.length == lineGradients.length);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        getDrawingVerticalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.1),
          strokeWidth: 0.5,
        ),
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.1),
          strokeWidth: 0.5,
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              final textStyle = TextStyle(
                color: touchedSpot.bar.gradient?.colors.first ??
                    touchedSpot.bar.color ??
                    Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              );
              return LineTooltipItem(
                touchedSpot.y.toStringAsFixed(2),
                textStyle,
              );
            }).toList();
          },
          getTooltipColor: (LineBarSpot touchedSpot) {
            return Colors.black.withOpacity(0.5);
          },
        ),
      ),
      titlesData: const FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 5,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        for (int i = 0; i < spots.length; i++)
          LineChartBarData(
            spots: spots[i],
            isCurved: true,
            curveSmoothness: curveSmoothness,
            gradient: lineGradients[i],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  lineGradients[i].colors.first.withOpacity(0.3),
                  lineGradients[i].colors.last.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegend(Color actualColor, Color commandedColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLegendItem('Actual', actualColor),
          const SizedBox(width: 8),
          _buildLegendItem('Commanded', commandedColor),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}

class TelemetryPainter extends CustomPainter {
  final FieldImage fieldImage;
  final Size robotSize;
  final Pose2d? currentPose;
  final Pose2d? targetPose;
  final List<Pose2d>? currentPath;
  final ColorScheme colorScheme;

  static double scale = 1;

  const TelemetryPainter({
    required this.fieldImage,
    required this.robotSize,
    this.currentPose,
    this.targetPose,
    this.currentPath,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    if (currentPath != null) {
      Paint p = Paint()
        ..color = colorScheme.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      Path path = Path();
      for (int i = 0; i < currentPath!.length; i++) {
        Offset offset = PathPainterUtil.pointToPixelOffset(
            currentPath![i].translation, scale, fieldImage);
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }

      canvas.drawPath(path, p);
    }

    if (targetPose != null) {
      PathPainterUtil.paintRobotOutline(
          targetPose!,
          fieldImage,
          robotSize,
          scale,
          canvas,
          Colors.grey[600]!.withOpacity(0.75),
          colorScheme.surfaceContainer);
    }

    if (currentPose != null) {
      PathPainterUtil.paintRobotOutline(currentPose!, fieldImage, robotSize,
          scale, canvas, colorScheme.primary, colorScheme.surfaceContainer);
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
