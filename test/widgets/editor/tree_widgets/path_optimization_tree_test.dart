import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path_optimization_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late ChangeStack undoStack;
  late PathPlannerPath path;
  late SharedPreferences prefs;

  setUp(() async {
    undoStack = ChangeStack();
    path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.pathOptimizationExpanded = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('tapping expands/collapses tree', (widgetTester) async {
    path.waypointsExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathOptimizationTree(
          path: path,
          undoStack: undoStack,
          prefs: prefs,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(
        find.descendant(
            of: find.byType(TreeCardNode), matching: find.byType(TreeCardNode)),
        findsNothing);

    await widgetTester.tap(find.byType(PathOptimizationTree));
    await widgetTester.pumpAndSettle();
    expect(path.pathOptimizationExpanded, true);

    await widgetTester.tap(find.text(
        'Path Optimizer')); // Use text so it doesn't tap middle of expanded card
    await widgetTester.pumpAndSettle();
    expect(path.pathOptimizationExpanded, false);
  });

  testWidgets('widget builds', (widgetTester) async {
    // Basic test to make sure the widget builds. Can't really
    // test the buttons since we can't wait for the isolate from this test
    path.pathOptimizationExpanded = true;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathOptimizationTree(
          path: path,
          undoStack: undoStack,
          prefs: prefs,
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    // For some reason flutter thinks elevated button w/ icon is not an elevated button
    expect(find.text('Optimize'), findsOne);
    expect(find.text('Discard'), findsOne);
    expect(find.text('Accept'), findsOne);

    expect(find.byType(LinearProgressIndicator), findsOne);
  });
}
