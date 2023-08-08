import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/add_command_button.dart';

void main() {
  testWidgets('button dropdown works', (widgetTester) async {
    String? chosenType;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddCommandButton(
          onTypeChosen: (type) => chosenType = type,
          allowPathCommand: true,
        ),
      ),
    ));

    expect(find.byTooltip('Add Command'), findsOneWidget);

    await widgetTester.tap(find.byType(AddCommandButton));
    await widgetTester.pumpAndSettle();

    expect(find.text('Follow Path'), findsOneWidget);
    expect(find.text('Named Command'), findsOneWidget);
    expect(find.text('Wait Command'), findsOneWidget);
    expect(find.text('Sequential Command Group'), findsOneWidget);
    expect(find.text('Parallel Command Group'), findsOneWidget);
    expect(find.text('Parallel Race Group'), findsOneWidget);
    expect(find.text('Parallel Deadline Group'), findsOneWidget);

    await widgetTester.tap(find.text('Wait Command'));
    await widgetTester.pumpAndSettle();

    expect(chosenType, 'wait');
  });
}
