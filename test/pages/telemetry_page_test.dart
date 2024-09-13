import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pathplanner/pages/telemetry_page.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'telemetry_page_test.mocks.dart';

@GenerateMocks([PPLibTelemetry])
void main() {
  late SharedPreferences prefs;
  late MockPPLibTelemetry telemetry;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    telemetry = MockPPLibTelemetry();

    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => Stream.value(false).asBroadcastStream());
    when(telemetry.velocitiesStream())
        .thenAnswer((_) => Stream.value([0, 0, 0, 0]).asBroadcastStream());
    when(telemetry.inaccuracyStream())
        .thenAnswer((_) => Stream.value(0).asBroadcastStream());
    when(telemetry.currentPoseStream())
        .thenAnswer((_) => Stream.value(null).asBroadcastStream());
    when(telemetry.targetPoseStream())
        .thenAnswer((_) => Stream.value(null).asBroadcastStream());
    when(telemetry.currentPathStream())
        .thenAnswer((_) => Stream.value(null).asBroadcastStream());
  });

  testWidgets('TelemetryPage shows loading indicator when not connected',
      (WidgetTester tester) async {
    when(telemetry.isConnected).thenReturn(false);
    when(telemetry.getServerAddress()).thenReturn('localhost');

    await tester.binding.setSurfaceSize(const Size(1280, 720));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TelemetryPage(
          fieldImage: FieldImage.defaultField,
          telemetry: telemetry,
          prefs: prefs,
        ),
      ),
    ));

    // Initial pump to build the widget tree
    await tester.pump();

    // Allow time for animations and async operations
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // Verify the loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Attempting to connect to robot...'), findsOneWidget);
    expect(find.text('Current Server Address: localhost'), findsOneWidget);

    // Verify that the graph widgets are not present
    expect(find.byType(LineChart), findsNothing);

    // Verify the connection tips are present
    expect(find.text('Please ensure that:'), findsOneWidget);
    expect(find.text('The robot is powered on'), findsOneWidget);
    expect(
        find.text('You are connected to the correct network'), findsOneWidget);
    expect(find.text('The robot code is running'), findsOneWidget);
  });
}
