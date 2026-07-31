import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/pathplanner_auto.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path2_starting_pose_tree.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

void main() {
  late Path2Auto auto;
  late ChangeStack undoStack;
  late int autoChangedCount;

  setUp(() {
    auto = Path2Auto(
      name: 'Test Auto',
      nodes: [],
      startingPose: Pose2d(
        const Translation2d(1.25, 2.5),
        Rotation2d.fromDegrees(45),
      ),
      startingPoseInitialized: false,
      autoDir: '/autos',
      fs: MemoryFileSystem(),
    );
    undoStack = ChangeStack();
    autoChangedCount = 0;
  });

  Future<void> pumpTree(
    WidgetTester tester, {
    bool initiallyExpanded = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: Path2StartingPoseTree(
              auto: auto,
              undoStack: undoStack,
              initiallyExpanded: initiallyExpanded,
              onAutoChanged: () => autoChangedCount++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    final field = find.widgetWithText(NumberTextField, label);
    expect(field, findsOneWidget);
    await tester.enterText(field, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('shows a pose summary and expands to three fields',
      (tester) async {
    await pumpTree(tester, initiallyExpanded: false);

    expect(find.text('Starting Pose'), findsOneWidget);
    expect(find.text('X: 1.25 M, Y: 2.50 M, 45.00\u00b0'), findsOneWidget);
    expect(find.byType(NumberTextField), findsNothing);

    await tester.tap(find.text('Starting Pose'));
    await tester.pumpAndSettle();

    expect(
        find.widgetWithText(NumberTextField, 'X Position (M)'), findsOneWidget);
    expect(
        find.widgetWithText(NumberTextField, 'Y Position (M)'), findsOneWidget);
    expect(
        find.widgetWithText(NumberTextField, 'Heading (Deg)'), findsOneWidget);
  });

  testWidgets('x submit is one undoable initialized-pose change',
      (tester) async {
    await pumpTree(tester);

    await submit(tester, 'X Position (M)', '3.75');

    expect(auto.startingPose.x, 3.75);
    expect(auto.startingPose.y, 2.5);
    expect(auto.startingPose.rotation.degrees, closeTo(45, 0.001));
    expect(auto.startingPoseInitialized, isTrue);
    expect(autoChangedCount, 1);
    expect(undoStack.canUndo, isTrue);

    undoStack.undo();
    expect(auto.startingPose.x, 1.25);
    expect(auto.startingPoseInitialized, isFalse);
    expect(autoChangedCount, 2);
    expect(undoStack.canUndo, isFalse);

    undoStack.redo();
    expect(auto.startingPose.x, 3.75);
    expect(auto.startingPoseInitialized, isTrue);
    expect(autoChangedCount, 3);
  });

  testWidgets('y submit preserves x and heading and is undoable',
      (tester) async {
    await pumpTree(tester);

    await submit(tester, 'Y Position (M)', '-0.5');

    expect(auto.startingPose.x, 1.25);
    expect(auto.startingPose.y, -0.5);
    expect(auto.startingPose.rotation.degrees, closeTo(45, 0.001));
    expect(autoChangedCount, 1);

    undoStack.undo();
    expect(auto.startingPose.y, 2.5);
    expect(auto.startingPoseInitialized, isFalse);
  });

  testWidgets('heading submit normalizes degrees and is undoable',
      (tester) async {
    await pumpTree(tester);

    await submit(tester, 'Heading (Deg)', '200');

    expect(auto.startingPose.translation, const Translation2d(1.25, 2.5));
    expect(auto.startingPose.rotation.degrees, closeTo(-160, 0.001));
    expect(autoChangedCount, 1);

    undoStack.undo();
    expect(auto.startingPose.rotation.degrees, closeTo(45, 0.001));
    expect(auto.startingPoseInitialized, isFalse);
  });

  testWidgets('null and non-finite values are ignored', (tester) async {
    await pumpTree(tester);

    final xField = tester.widget<NumberTextField>(
      find.widgetWithText(NumberTextField, 'X Position (M)'),
    );
    xField.onSubmitted?.call(null);
    xField.onSubmitted?.call(double.infinity);
    await tester.pump();

    expect(auto.startingPose.x, 1.25);
    expect(auto.startingPoseInitialized, isFalse);
    expect(autoChangedCount, 0);
    expect(undoStack.canUndo, isFalse);
  });
}
