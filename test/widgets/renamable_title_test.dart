import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/renamable_title.dart';

void main() {
  testWidgets('renamable title', (widgetTester) async {
    bool renameCalled = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RenamableTitle(
          title: 'test',
          onRename: (value) {
            renameCalled = true;
          },
        ),
      ),
    ));

    var textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    expect(find.text('test'), findsOneWidget);

    // empty text
    await widgetTester.enterText(textField, '');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(renameCalled, false);

    // valid name
    await widgetTester.enterText(textField, 'valid name');
    expect(find.text('valid name'), findsOneWidget);
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();
    expect(renameCalled, true);

    // invalid characters
    await widgetTester.enterText(textField, 'remove"*<>?|/:_invalid');
    expect(find.text('remove_invalid'), findsOneWidget);
  });
}
