import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pathplanner/widgets/editor/graph_editor/path_branch_event_chips.dart';
import 'package:pathplanner/widgets/editor/graph_editor/visual_graph_editor.dart';

void main() {
  testWidgets(
    'liquid motion carries momentum through reversal and honors reduced motion',
    (tester) async {
      final near = ValueNotifier(false);
      final reduceMotion = ValueNotifier(false);
      addTearDown(near.dispose);
      addTearDown(reduceMotion.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: reduceMotion,
                builder: (context, reduced, _) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduced),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: near,
                    builder: (context, value, _) => GraphBranchProximity(
                      near: value,
                      child: SizedBox(
                        width: 220,
                        height: 28,
                        child: BranchEventChips(
                          branchId: 'motion',
                          names: const [],
                          transitionBadge: const Text('Finished'),
                          onEditTransition: () {},
                          onAdd: (_) {},
                          onRemove: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.byIcon(Icons.add_rounded);
      final visibility = find.byKey(
        const ValueKey('branchAddEventVisibility-motion'),
      );
      near.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final before = tester.getCenter(add).dx;
      near.value = false;
      await tester.pump();
      expect(tester.getCenter(add).dx, closeTo(before, 0.01));
      await tester.pump(const Duration(milliseconds: 8));
      expect(
        tester.getCenter(add).dx,
        greaterThan(before),
        reason: 'the droplet should decelerate with its existing momentum before returning',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(visibility).opacity, 0);
      reduceMotion.value = true;
      near.value = true;
      await tester.pump();
      expect(tester.widget<Opacity>(visibility).opacity, 1);
      near.value = false;
      await tester.pump();
      expect(tester.widget<Opacity>(visibility).opacity, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'branch proximity animates the bubble without moving the chip and keeps the picker open',
    (tester) async {
      String? added;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisualGraphEditor(
              nodes: const [
                VisualGraphNode(
                  id: 'a',
                  position: Offset(250, 40),
                  size: Size(100, 50),
                  child: SizedBox(),
                ),
                VisualGraphNode(
                  id: 'b',
                  position: Offset(250, 490),
                  size: Size(100, 50),
                  child: SizedBox(),
                ),
              ],
              branches: [
                VisualGraphBranch(
                  id: 'branch',
                  sourceId: 'a',
                  targetId: 'b',
                  customBadge: true,
                  badgeSize: BranchEventChips.sizeFor(0),
                  badge: BranchEventChips(
                    branchId: 'branch',
                    names: const [],
                    transitionBadge: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text('Finished')],
                    ),
                    onEditTransition: () {},
                    onAdd: (name) => added = name,
                    onRemove: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final opacityFinder = find.byKey(
        const ValueKey('branchAddEventVisibility-branch'),
      );
      double opacity() => tester.widget<Opacity>(opacityFinder).opacity;
      final transition = find.byKey(
        const ValueKey('editBranchTransition-branch'),
      );
      final originalRect = tester.getRect(transition);
      expect(opacity(), 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      addTearDown(mouse.removePointer);
      // Near the connection, well away from the transition badge.
      await mouse.moveTo(const Offset(322, 150));
      await tester.pumpAndSettle();
      expect(opacity(), 0);
      await mouse.moveTo(const Offset(312, 150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(opacity(), greaterThan(0));
      expect(opacity(), lessThan(1));
      expect(tester.getRect(transition), originalRect);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      await mouse.moveTo(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(opacity(), greaterThan(0));
      expect(opacity(), lessThan(1));
      await tester.pumpAndSettle();
      expect(opacity(), 0);
      await mouse.moveTo(tester.getCenter(transition));
      await tester.pumpAndSettle();
      final add = find.byIcon(Icons.add_rounded);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      await tester.enterText(find.byType(TextField), 'Bubble event');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create “Bubble event”'));
      await tester.pumpAndSettle();
      expect(added, 'Bubble event');
      expect(opacity(), 0);
      // Move once more after focus is restored to the anchor.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
