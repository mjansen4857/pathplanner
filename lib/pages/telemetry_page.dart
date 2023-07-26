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
          bool connected = snapshot.data ?? false;

          if (!connected) {
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
              const Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
                        child: Center(
                          child: Text('Graph'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
                        child: Center(
                          child: Text('Graph'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
                        child: Center(
                          child: Text('Graph'),
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
