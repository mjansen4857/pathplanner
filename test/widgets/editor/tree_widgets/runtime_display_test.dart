import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/editor/runtime_display.dart';

void main() {
  testWidgets('RuntimeDisplay shows current runtime',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RuntimeDisplay(
            currentRuntime: 5.0,
            previousRuntime: null,
          ),
        ),
      ),
    );

    expect(find.text('~5.00s'), findsOneWidget);
  });

  testWidgets('RuntimeDisplay shows runtime decrease',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RuntimeDisplay(
            currentRuntime: 4.5,
            previousRuntime: 5.0,
          ),
        ),
      ),
    );

    expect(find.text('~4.50s'), findsOneWidget);
    expect(find.text('(-0.50s)'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
  });

  testWidgets('RuntimeDisplay shows runtime increase',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RuntimeDisplay(
            currentRuntime: 5.5,
            previousRuntime: 5.0,
          ),
        ),
      ),
    );

    expect(find.text('~5.50s'), findsOneWidget);
    expect(find.text('(+0.50s)'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('RuntimeDisplay shows no significant change',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RuntimeDisplay(
            currentRuntime: 5.03,
            previousRuntime: 5.0,
          ),
        ),
      ),
    );

    expect(find.text('~5.03s'), findsOneWidget);
    expect(find.text('(+0.03s)'), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
  });
}
