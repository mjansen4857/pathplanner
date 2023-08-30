import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/number_text_field.dart';

void main() {
  testWidgets('enter text', (widgetTester) async {
    num? lastSubmit;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          initialText: '0.00',
          label: 'Test Label',
          onSubmitted: (value) {
            lastSubmit = value;
          },
        ),
      ),
    ));

    var textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('Test Label'), findsOneWidget);

    // empty text
    await widgetTester.enterText(textField, '');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(lastSubmit, isNull);

    // valid number
    await widgetTester.enterText(textField, '1.5');
    expect(find.text('1.5'), findsOneWidget);
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(lastSubmit, 1.5);

    // invalid characters
    await widgetTester.enterText(textField, '10.25.1asdf');
    expect(find.text('10.25'), findsOneWidget);
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(lastSubmit, 10.25);

    // evaluates expression
    await widgetTester.enterText(textField, '10*2.5');
    expect(find.text('10*2.5'), findsOneWidget);
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(lastSubmit, 25);
  });

  testWidgets('increment arrow key up', (widgetTester) async {
    num? lastSubmit;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          initialText: '0.00',
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (value) {
            lastSubmit = value;
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

    expect(lastSubmit, closeTo(1.0, 0.01));
  });

  testWidgets('increment arrow key up partial', (widgetTester) async {
    num? lastSubmit;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          initialText: '0.7',
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (value) {
            lastSubmit = value;
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

    expect(lastSubmit, closeTo(1.0, 0.01));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          initialText: '0.2',
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (value) {
            lastSubmit = value;
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

    expect(lastSubmit, closeTo(1.0, 0.01));
  });

  testWidgets('increment arrow key down', (widgetTester) async {
    num? lastSubmit;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          initialText: '0.00',
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (value) {
            lastSubmit = value;
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

    expect(lastSubmit, closeTo(-1.0, 0.01));
  });

  testWidgets('increment arrow key partial', (widgetTester) async {
    num? lastSubmit;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          initialText: '-0.20',
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (value) {
            lastSubmit = value;
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

    expect(lastSubmit, closeTo(-1.0, 0.01));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberTextField(
          initialText: '-0.70',
          label: 'Test Label',
          arrowKeyIncrement: 1.0,
          onSubmitted: (value) {
            lastSubmit = value;
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

    expect(lastSubmit, closeTo(-1.0, 0.01));
  });
}
