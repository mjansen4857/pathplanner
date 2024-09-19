import 'dart:async';

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

@GenerateNiceMocks([MockSpec<PPLibTelemetry>()])
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('loading when not connected', (widgetTester) async {
    var telemetry = MockPPLibTelemetry();

    final connectionStatusController = StreamController<bool>();
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => connectionStatusController.stream);
    when(telemetry.getServerAddress()).thenReturn('localhost:5811');
    when(telemetry.velocitiesStream()).thenAnswer((_) => const Stream.empty());
    when(telemetry.inaccuracyStream()).thenAnswer((_) => const Stream.empty());
    when(telemetry.currentPoseStream()).thenAnswer((_) => Stream.value(null));
    when(telemetry.targetPoseStream()).thenAnswer((_) => Stream.value(null));
    when(telemetry.currentPathStream()).thenAnswer((_) => Stream.value(null));

    connectionStatusController.add(false);

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TelemetryPage(
          fieldImage: FieldImage.defaultField,
          telemetry: telemetry,
          prefs: prefs,
        ),
      ),
    ));

    await widgetTester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Attempting to connect to robot...'), findsOneWidget);
    expect(find.text('Current Server Address: localhost:5811'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);

    // Clean up
    addTearDown(connectionStatusController.close);
  });

  testWidgets('displays data when connected', (widgetTester) async {
    var telemetry = MockPPLibTelemetry();

    final connectionStatusController = StreamController<bool>();
    final velocitiesController = StreamController<List<num>>();
    final inaccuracyController = StreamController<num>();
    final currentPoseController = StreamController<List<num>>();
    final targetPoseController = StreamController<List<num>>();
    final currentPathController = StreamController<List<num>>();

    when(telemetry.getServerAddress()).thenReturn('localhost:5811');
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => connectionStatusController.stream);
    when(telemetry.velocitiesStream())
        .thenAnswer((_) => velocitiesController.stream);
    when(telemetry.inaccuracyStream())
        .thenAnswer((_) => inaccuracyController.stream);
    when(telemetry.currentPoseStream())
        .thenAnswer((_) => currentPoseController.stream);
    when(telemetry.targetPoseStream())
        .thenAnswer((_) => targetPoseController.stream);
    when(telemetry.currentPathStream())
        .thenAnswer((_) => currentPathController.stream);

    connectionStatusController.add(true);

    await widgetTester.binding.setSurfaceSize(const Size(1280, 720));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TelemetryPage(
          fieldImage: FieldImage.defaultField,
          telemetry: telemetry,
          prefs: prefs,
        ),
      ),
    ));

    // Add some data to the streams
    velocitiesController.add([1.0, 2.0, 0.5, 1.5]);
    inaccuracyController.add(0.25);
    currentPoseController.add([2.1, 2.1, 20]);
    targetPoseController.add([2, 2, 0]);
    currentPathController.add([1, 5, 2, 4, 3, 5]);

    // Allow time for the streams to emit some values
    await widgetTester.pump(const Duration(milliseconds: 100));
    await widgetTester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LineChart), findsNWidgets(3)); // Expect 3 LineCharts
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Robot Velocity'), findsOneWidget);
    expect(find.text('Angular Velocity'), findsOneWidget);
    expect(find.text('Path Inaccuracy'), findsOneWidget);

    // Clean up
    addTearDown(() {
      connectionStatusController.close();
      velocitiesController.close();
      inaccuracyController.close();
      currentPoseController.close();
      targetPoseController.close();
      currentPathController.close();
    });
  });

  testWidgets('TelemetryPage handles connection status changes',
      (WidgetTester tester) async {
    var telemetry = MockPPLibTelemetry();

    final connectionStatusController = StreamController<bool>.broadcast();
    final velocitiesController = StreamController<List<num>>();
    final inaccuracyController = StreamController<num>();
    final currentPoseController = StreamController<List<num>?>();
    final targetPoseController = StreamController<List<num>?>();
    final currentPathController = StreamController<List<num>?>();

    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => connectionStatusController.stream);
    when(telemetry.velocitiesStream())
        .thenAnswer((_) => velocitiesController.stream);
    when(telemetry.inaccuracyStream())
        .thenAnswer((_) => inaccuracyController.stream);
    when(telemetry.currentPoseStream())
        .thenAnswer((_) => currentPoseController.stream);
    when(telemetry.targetPoseStream())
        .thenAnswer((_) => targetPoseController.stream);
    when(telemetry.currentPathStream())
        .thenAnswer((_) => currentPathController.stream);
    when(telemetry.getServerAddress()).thenReturn('localhost:5811');

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

    // Initially disconnected
    connectionStatusController.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Attempting to connect to robot...'), findsOneWidget);

    // Connect
    connectionStatusController.add(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LineChart), findsNWidgets(3));

    // Disconnect again
    connectionStatusController.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Attempting to connect to robot...'), findsOneWidget);

    // Clean up
    addTearDown(() {
      connectionStatusController.close();
      velocitiesController.close();
      inaccuracyController.close();
      currentPoseController.close();
      targetPoseController.close();
      currentPathController.close();
    });
  });

  testWidgets('TelemetryPage updates inaccuracy graph',
      (WidgetTester tester) async {
    var telemetry = MockPPLibTelemetry();

    final connectionStatusController = StreamController<bool>.broadcast();
    final velocitiesController = StreamController<List<num>>();
    final inaccuracyController = StreamController<num>.broadcast();
    final currentPoseController = StreamController<List<num>?>();
    final targetPoseController = StreamController<List<num>?>();
    final currentPathController = StreamController<List<num>?>();

    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => connectionStatusController.stream);
    when(telemetry.velocitiesStream())
        .thenAnswer((_) => velocitiesController.stream);
    when(telemetry.inaccuracyStream())
        .thenAnswer((_) => inaccuracyController.stream);
    when(telemetry.currentPoseStream())
        .thenAnswer((_) => currentPoseController.stream);
    when(telemetry.targetPoseStream())
        .thenAnswer((_) => targetPoseController.stream);
    when(telemetry.currentPathStream())
        .thenAnswer((_) => currentPathController.stream);
    when(telemetry.getServerAddress()).thenReturn('localhost:5811');

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

    // Simulate connected state
    connectionStatusController.add(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Add inaccuracy data
    inaccuracyController.add(0.5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the inaccuracy graph is updated
    final inaccuracyGraph = find.byWidgetPredicate(
      (Widget widget) =>
          widget is LineChart &&
          widget.data.lineBarsData.isNotEmpty &&
          widget.data.lineBarsData.first.spots.isNotEmpty,
    );
    expect(inaccuracyGraph, findsOneWidget);

    // Verify the inaccuracy value
    final lineChart = tester.widget<LineChart>(inaccuracyGraph);
    expect(lineChart.data.lineBarsData.first.spots.last.y, 0.5);

    // Clean up
    addTearDown(() {
      connectionStatusController.close();
      velocitiesController.close();
      inaccuracyController.close();
      currentPoseController.close();
      targetPoseController.close();
      currentPathController.close();
    });
  });
}
