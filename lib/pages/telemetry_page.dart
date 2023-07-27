import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/widgets/field_image.dart';

class TelemetryPage extends StatefulWidget {
  final FieldImage fieldImage;

  const TelemetryPage({
    super.key,
    required this.fieldImage,
  });

  @override
  State<TelemetryPage> createState() => _TelemetryPageState();
}

class _TelemetryPageState extends State<TelemetryPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: PPLibTelemetry.connectionStatusStream(),
        builder: (context, snapshot) {
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
                    const Expanded(
                      flex: 2,
                      child: Center(
                        child: Text('Path following testing/config'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
                        child: Stack(
                          children: [
                            Center(
                              child: LineChart(_testVelData()),
                            ),
                            const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Text(
                                  'Robot Velocity',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Text('Actual'),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: Colors.deepPurple,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Text('Commanded'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
                        child: Stack(
                          children: [
                            Center(
                              child: LineChart(_testAngVelData()),
                            ),
                            const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Text(
                                  'Angular Velocity',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Text('Actual'),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Text('Commanded'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
                        child: Stack(
                          children: [
                            Center(
                              child: LineChart(_testInnaccuracyData()),
                            ),
                            const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Text(
                                  'Path Innaccuracy',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        });
  }

  LineChartData _testVelData() {
    return LineChartData(
      gridData: const FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        verticalInterval: 3,
        horizontalInterval: 1,
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
      maxY: 6,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 3),
            FlSpot(3, 2),
            FlSpot(7, 5),
            FlSpot(12, 3.5),
            FlSpot(15, 1),
          ],
          shadow: const Shadow(offset: Offset(0, 5), blurRadius: 4),
          isCurved: true,
          gradient: const LinearGradient(
            colors: [
              Colors.deepPurple,
              Colors.deepPurpleAccent,
            ],
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: const [
            FlSpot(0, 4),
            FlSpot(3, 3),
            FlSpot(7, 2.5),
            FlSpot(12, 4.5),
            FlSpot(15, 2),
          ],
          isCurved: true,
          shadow: const Shadow(offset: Offset(0, 5), blurRadius: 4),
          gradient: const LinearGradient(
            colors: [
              Colors.green,
              Colors.greenAccent,
            ],
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  LineChartData _testAngVelData() {
    return LineChartData(
      gridData: const FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        verticalInterval: 3,
        horizontalInterval: 180,
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
      maxY: 720,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 400),
            FlSpot(3, 300),
            FlSpot(7, 600),
            FlSpot(12, 450),
            FlSpot(15, 200),
          ],
          shadow: const Shadow(offset: Offset(0, 5), blurRadius: 4),
          isCurved: true,
          gradient: const LinearGradient(
            colors: [
              Colors.blue,
              Colors.blueAccent,
            ],
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: const [
            FlSpot(0, 500),
            FlSpot(3, 400),
            FlSpot(7, 350),
            FlSpot(12, 550),
            FlSpot(15, 300),
          ],
          isCurved: true,
          shadow: const Shadow(offset: Offset(0, 5), blurRadius: 4),
          gradient: const LinearGradient(
            colors: [
              Colors.orange,
              Colors.orangeAccent,
            ],
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  LineChartData _testInnaccuracyData() {
    return LineChartData(
      gridData: const FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        verticalInterval: 3,
        horizontalInterval: 0.25,
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
      maxY: 1,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 0.2),
            FlSpot(3, 0.3),
            FlSpot(7, 0.3),
            FlSpot(12, 0.45),
            FlSpot(15, 0.2),
          ],
          shadow: const Shadow(offset: Offset(0, 5), blurRadius: 4),
          isCurved: true,
          gradient: const LinearGradient(
            colors: [
              Colors.red,
              Colors.redAccent,
            ],
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      ],
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
