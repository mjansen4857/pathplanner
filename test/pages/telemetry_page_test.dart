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

    when(telemetry.isConnected).thenReturn(false);
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => Stream.value(false));

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
    await widgetTester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('displays data when connected', (widgetTester) async {
    var telemetry = MockPPLibTelemetry();

    when(telemetry.isConnected).thenReturn(true);
    when(telemetry.connectionStatusStream())
        .thenAnswer((_) => Stream.value(true));
    when(telemetry.velocitiesStream())
        .thenAnswer((_) => Stream.value([0, 0, 0, 0]));
    when(telemetry.inaccuracyStream()).thenAnswer((_) => Stream.value(0));
    when(telemetry.currentPoseStream())
        .thenAnswer((_) => Stream.value([2.1, 2.1, 20]));
    when(telemetry.targetPoseStream())
        .thenAnswer((_) => Stream.value([2, 2, 0]));
    when(telemetry.currentPathStream())
        .thenAnswer((_) => Stream.value([1, 5, 2, 4, 3, 5]));

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
    await widgetTester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LineChart), findsWidgets);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
