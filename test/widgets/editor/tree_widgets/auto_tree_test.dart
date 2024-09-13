import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/auto_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/reset_odom_tree.dart';
import 'package:undo/undo.dart';

void main() {
  late PathPlannerAuto auto;
  bool sideSwapped = false;

  setUp(() {
    auto = PathPlannerAuto.defaultAuto(
      autoDir: '/autos',
      fs: MemoryFileSystem(),
    );
    sideSwapped = false;
  });

  testWidgets('has simulated driving time', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoTree(
          auto: auto,
          undoStack: ChangeStack(),
          allPathNames: const [],
        ),
      ),
    ));

    expect(find.textContaining('Simulated Driving Time'), findsOneWidget);
  });

  testWidgets('swap side button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoTree(
          auto: auto,
          undoStack: ChangeStack(),
          allPathNames: const [],
          onSideSwapped: () => sideSwapped = true,
        ),
      ),
    ));

    var btn = find.byTooltip('Move to Other Side');

    expect(btn, findsOneWidget);

    await widgetTester.tap(btn);
    await widgetTester.pump();
    expect(sideSwapped, true);
  });

  testWidgets('has command group', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoTree(
          auto: auto,
          undoStack: ChangeStack(),
          allPathNames: const [],
        ),
      ),
    ));

    expect(find.byType(CommandGroupWidget), findsWidgets);
  });

  testWidgets('has reset odom check', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoTree(
          auto: auto,
          undoStack: ChangeStack(),
          allPathNames: const [],
        ),
      ),
    ));

    expect(find.byType(ResetOdomTree), findsWidgets);
  });
}
