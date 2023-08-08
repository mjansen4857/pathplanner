import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';

void main() {
  testWidgets('tree card node', (widgetTester) async {
    bool hoverStarted = false;
    bool hoverEnded = false;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TreeCardNode(
          title: const Text('test_card'),
          initiallyExpanded: false,
          onHoverStart: () => hoverStarted = true,
          onHoverEnd: () => hoverEnded = true,
          children: const [
            Text('child_text'),
          ],
        ),
      ),
    ));

    expect(find.text('test_card'), findsOneWidget);
    expect(find.text('child_text'), findsNothing);

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await widgetTester.pump();

    expect(hoverStarted, false);
    expect(hoverEnded, false);

    final treeCard = find.byType(TreeCardNode);

    await gesture.moveTo(widgetTester.getCenter(treeCard));
    await widgetTester.pumpAndSettle();

    expect(hoverStarted, true);
    expect(hoverEnded, false);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pumpAndSettle();

    expect(hoverEnded, true);

    await widgetTester.tap(treeCard);
    await widgetTester.pumpAndSettle();

    expect(find.text('child_text'), findsOneWidget);
  });
}
