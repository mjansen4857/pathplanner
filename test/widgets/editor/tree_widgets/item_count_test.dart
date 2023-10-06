import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/item_count.dart';

void main() {
  testWidgets('item count', (widgetTester) async {
    await widgetTester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ItemCount(count: 5),
        ),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await widgetTester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ItemCount(count: 7),
        ),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
