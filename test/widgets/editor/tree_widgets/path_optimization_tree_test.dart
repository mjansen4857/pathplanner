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
    path.pathOptimizationExpanded = false;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathOptimizationTree(
          path: path,
          undoStack: undoStack,
          prefs: prefs,
          fieldSizeMeters: const Size(16.54, 8.21),
        ),
      ),
    ));

    expect(find.byType(TreeCardNode), findsOneWidget);
    expect(find.text('Path Optimizer'), findsOneWidget);
    expect(find.byIcon(Icons.query_stats), findsOneWidget);

    await widgetTester.tap(find.byType(TreeCardNode));
    await widgetTester.pumpAndSettle();
    expect(path.pathOptimizationExpanded, true);

    await widgetTester.tap(find.text('Path Optimizer'));
    await widgetTester.pumpAndSettle();
    expect(path.pathOptimizationExpanded, false);
  });

  testWidgets('widget builds and displays correctly', (widgetTester) async {
    path.pathOptimizationExpanded = true;
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathOptimizationTree(
          path: path,
          undoStack: undoStack,
          prefs: prefs,
          fieldSizeMeters: const Size(16.54, 8.21),
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    expect(find.text('Path Optimizer'), findsOneWidget);
    expect(find.byIcon(Icons.query_stats), findsOneWidget);
    expect(find.text('Optimized Runtime: 0.00s'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('Optimize'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
