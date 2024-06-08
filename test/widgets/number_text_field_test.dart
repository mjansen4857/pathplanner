import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/number_text_field.dart';

void main() {
  testWidgets('enter text', (widgetTester) async {
    num value = 0;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          value: value,
          label: 'Test Label',
          onSubmitted: (newValue) {
            value = newValue;
          },
        ),
      ),
    ));

    var textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Test Label'), findsOneWidget);

    // valid number
    await widgetTester.enterText(textField, '1.5');
    expect(find.text('1.5'), findsOneWidget);
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(value, closeTo(1.5, 0.00001));

    // invalid characters are ignored
    await widgetTester.enterText(textField, '10.25.1asdf');
    expect(find.text('10.25'), findsOneWidget);
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(value, closeTo(10.25, 0.00001));

    // evaluates expression
    await widgetTester.enterText(textField, '10*2.5');
    expect(find.text('10*2.5'), findsOneWidget);
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(value, closeTo(25, 0.00001));
  });

  testWidgets('increment arrow key up', (widgetTester) async {
    num value = 0;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          value: value,
          label: 'Test Label',
          arrowKeyIncrement: 1,
          onSubmitted: (newValue) {
            value = newValue;
          },
        ),
      ),
    ));

    var textField = find.byType(TextField);
    await widgetTester.tap(textField);

    await widgetTester.pumpAndSettle();

    await simulateKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await widgetTester.pump();
    await simulateKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await widgetTester.pump();

    expect(value, closeTo(2.0, 0.00001));
  });

  testWidgets('increment arrow key up partial', (widgetTester) async {
    num value = 0.7;

    await widgetTester.pumpWidget(
      MaterialApp(
          home: Scaffold(
        body: NumberTextField(
          value: value,
          label: 'Test Label',
          arrowKeyIncrement: 0.1,
          onSubmitted: (newValue) {
            value = newValue;
          },
        ),
      )),
    );

    var textField = find.byType(TextField);
    await widgetTester.tap(textField);

    await widgetTester.pumpAndSettle();

    await simulateKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await widgetTester.pump();
    await simulateKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await widgetTester.pump();

    expect(value, closeTo(0.9, 0.00001));

    value = 0.2;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          value: value,
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (newValue) {
            value = newValue;
          },
        ),
      ),
    ));

    textField = find.byType(TextField);
    await widgetTester.tap(textField);

    await widgetTester.pumpAndSettle();

    await simulateKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await widgetTester.pump();
    await simulateKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await widgetTester.pump();

    expect(value, closeTo(0.6, 0.0001));
  });

  testWidgets('increment arrow key down', (widgetTester) async {
    num value = 0;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          value: value,
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (newValue) {
            value = newValue;
          },
        ),
      ),
    ));

    var textField = find.byType(TextField);
    await widgetTester.tap(textField);

    await widgetTester.pumpAndSettle();

    await simulateKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await widgetTester.pump();
    await simulateKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await widgetTester.pump();

    expect(value, closeTo(-2.0, 0.00001));
  });

  testWidgets('increment arrow key partial', (widgetTester) async {
    num value = -0.2;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          value: value,
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (newValue) {
            value = newValue;
          },
        ),
      ),
    ));

    var textField = find.byType(TextField);
    await widgetTester.tap(textField);

    await widgetTester.pumpAndSettle();

    await simulateKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await widgetTester.pump();
    await simulateKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await widgetTester.pump();

    expect(value, closeTo(-2.2, 0.00001));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          value: -0.70,
          label: 'Test Label',
          arrowKeyIncrement: 0.15,
          onSubmitted: (newValue) {
            value = newValue;
          },
        ),
      ),
    ));

    textField = find.byType(TextField);
    await widgetTester.tap(textField);

    await widgetTester.pumpAndSettle();

    await simulateKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await widgetTester.pump();
    await simulateKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await widgetTester.pump();

    expect(value, closeTo(-1.0, 0.00001));
  });
}
