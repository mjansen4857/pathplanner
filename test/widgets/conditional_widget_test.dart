import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';

void main() {
  testWidgets('conditional widget true', (widgetTester) async {
    await widgetTester.pumpWidget(const MaterialApp(
      home: ConditionalWidget(
        condition: true,
        trueChild: Text('true'),
        falseChild: Text('false'),
      ),
    ));

    final trueFinder = find.text('true');
    final falseFinder = find.text('false');

    expect(trueFinder, findsOneWidget);
    expect(falseFinder, findsNothing);
  });

  testWidgets('conditional widget false', (widgetTester) async {
    await widgetTester.pumpWidget(const MaterialApp(
      home: ConditionalWidget(
        condition: false,
        trueChild: Text('true'),
        falseChild: Text('false'),
      ),
    ));

    final trueFinder = find.text('true');
    final falseFinder = find.text('false');

    expect(trueFinder, findsNothing);
    expect(falseFinder, findsOneWidget);
  });
}
