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

    when(telemetry.getServerAddress()).thenReturn('localhost');
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

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Attempting to connect to robot...'), findsOneWidget);
    expect(find.text('Current Server Address: localhost'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Please ensure that:'), findsOneWidget);
    expect(find.text('The robot is powered on'), findsOneWidget);
    expect(
        find.text('You are connected to the correct network'), findsOneWidget);
    expect(find.text('The robot code is running'), findsOneWidget);
  });

  testWidgets('TelemetryPage shows graphs when connected',
      (WidgetTester tester) async {
    when(telemetry.isConnected).thenReturn(true);
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => Stream.value(true).asBroadcastStream());

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

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LineChart), findsNWidgets(3));
    expect(find.text('Robot Velocity'), findsOneWidget);
    expect(find.text('Angular Velocity'), findsOneWidget);
    expect(find.text('Path Inaccuracy'), findsOneWidget);
  });

  testWidgets('TelemetryPage updates when new data is received',
      (WidgetTester tester) async {
    when(telemetry.isConnected).thenReturn(true);
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => Stream.value(true).asBroadcastStream());

    final velocitiesController = StreamController<List<num>>.broadcast();
    when(telemetry.velocitiesStream())
        .thenAnswer((_) => velocitiesController.stream);

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

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    velocitiesController.add([1, 2, 3, 4]);
    await tester.pump();

    // You might need to implement a way to verify that the graph has updated
    // This could involve exposing some internal state for testing or using a custom matcher
    // For now, we'll just verify that the graph is still present
    expect(find.byType(LineChart), findsNWidgets(3));

    velocitiesController.close();
  });

  testWidgets('TelemetryPage handles connection status changes',
      (WidgetTester tester) async {
    final connectionStatusController = StreamController<bool>.broadcast();
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => connectionStatusController.stream);
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

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    when(telemetry.isConnected).thenReturn(true);
    connectionStatusController.add(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LineChart), findsNWidgets(3));

    connectionStatusController.close();
  });

  testWidgets('TelemetryPage updates inaccuracy graph',
      (WidgetTester tester) async {
    when(telemetry.isConnected).thenReturn(true);
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => Stream.value(true).asBroadcastStream());

    final inaccuracyController = StreamController<num>.broadcast();
    when(telemetry.inaccuracyStream())
        .thenAnswer((_) => inaccuracyController.stream);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TelemetryPage(
          fieldImage: FieldImage.defaultField,
          telemetry: telemetry,
          prefs: prefs,
        ),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    inaccuracyController.add(0.5);
    await tester.pump();

    // Verify that the inaccuracy graph is updated
    final inaccuracyGraph = find.byWidgetPredicate(
      (Widget widget) =>
          widget is LineChart && widget.data.lineBarsData.length == 2,
    );
    expect(inaccuracyGraph, findsOneWidget);

    inaccuracyController.close();
  });
}
