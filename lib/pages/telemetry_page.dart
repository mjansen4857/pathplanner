import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/widgets/field_image.dart';

class TelemetryPage extends StatefulWidget {
  final FieldImage fieldImage;
  final PPLibTelemetry telemetry;

  const TelemetryPage({
    super.key,
    required this.fieldImage,
    required this.telemetry,
  });

  @override
  State<TelemetryPage> createState() => _TelemetryPageState();
}

class _TelemetryPageState extends State<TelemetryPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.telemetry.connectionStatusStream(),
        builder: (context, snapshot) {
          ColorScheme colorScheme = Theme.of(context).colorScheme;
          // bool connected = snapshot.data ?? false;

          // if (!connected) {
          //   return const Center(
          //     child: Column(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: [
          //         CircularProgressIndicator(),
          //         SizedBox(height: 16),
          //         Text('Attempting to connect to robot...'),
          //       ],
          //     ),
          //   );
          // }

          return Column(
            children: [
              Expanded(
                flex: 7,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Stack(
                          children: [
                            widget.fieldImage.getWidget(),
                            const Positioned.fill(
                              child: CustomPaint(
                                painter: TelemetryPainter(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colorScheme.primary,
                              size: 76,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                                'No auto builder detected in robot code.'),
                            const SizedBox(height: 16),
                            const Text(
                                'An auto builder is required to test path following'),
                            const Text('commands from the GUI.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                        spots: const [
                          [
                            FlSpot(0, 3),
                            FlSpot(3, 2),
                            FlSpot(7, 5),
                            FlSpot(12, 3.5),
                            FlSpot(15, 1),
                          ],
                          [
                            FlSpot(0, 4),
                            FlSpot(3, 3),
                            FlSpot(7, 2.5),
                            FlSpot(12, 4.5),
                            FlSpot(15, 2),
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
                        maxY: 720,
                        horizontalInterval: 180,
                        spots: const [
                          [
                            FlSpot(0, 400),
                            FlSpot(3, 300),
                            FlSpot(7, 600),
                            FlSpot(12, 450),
                            FlSpot(15, 200),
                          ],
                          [
                            FlSpot(0, 500),
                            FlSpot(3, 400),
                            FlSpot(7, 350),
                            FlSpot(12, 550),
                            FlSpot(15, 300),
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
                      title: 'Path Innaccuracy',
                      data: _buildData(
                        maxY: 1.0,
                        horizontalInterval: 0.25,
                        spots: const [
                          [
                            FlSpot(0, 0.2),
                            FlSpot(3, 0.3),
                            FlSpot(7, 0.3),
                            FlSpot(12, 0.45),
                            FlSpot(15, 0.2),
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
                  ],
                ),
              ),
            ],
          );
        });
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
              child: LineChart(data),
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
    double? horizontalInterval,
  }) {
    assert(spots.length == lineGradients.length);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        verticalInterval: 3,
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
      maxX: 15,
      minY: 0,
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
  static double scale = 1;

  const TelemetryPainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
