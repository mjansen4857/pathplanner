import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/number_text_field.dart';

void main() {
  testWidgets('number text field', (widgetTester) async {
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
}
