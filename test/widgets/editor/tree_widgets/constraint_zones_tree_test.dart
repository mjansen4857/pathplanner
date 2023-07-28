import 'package:file/memory.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/constraint_zones_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:undo/undo.dart';

void main() {
  testWidgets('constraint zones tree', (widgetTester) async {
    PathPlannerPath path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.constraintZones = [
      ConstraintsZone(
        constraints: PathConstraints(),
        minWaypointRelativePos: 0.2,
        maxWaypointRelativePos: 0.8,
        name: '0',
      ),
      ConstraintsZone(
        constraints: PathConstraints(),
        minWaypointRelativePos: 1.2,
        maxWaypointRelativePos: 1.8,
        name: '1',
      ),
    ];
    var undoStack = ChangeStack();

    bool pathChanged = false;
    int? hoveredZone;
    int? selectedZone;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConstraintZonesTree(
          path: path,
          onPathChanged: () => pathChanged = true,
          onZoneHovered: (value) => hoveredZone = value,
          onZoneSelected: (value) => selectedZone = value,
          undoStack: undoStack,
        ),
      ),
    ));

    // Tree initially collapsed, expect to find nothing
    expect(find.byType(RenamableTitle), findsNothing);

    await widgetTester.tap(find.byType(ConstraintZonesTree));
    await widgetTester.pumpAndSettle();

    expect(path.constraintZonesExpanded, true);
    var zoneTrees = find.ancestor(
        of: find.byType(RenamableTitle),
        matching: find.descendant(
            of: find.byType(TreeCardNode),
            matching: find.byType(TreeCardNode)));
    expect(zoneTrees, findsNWidgets(2));

    final gesture =
        await widgetTester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(widgetTester.getCenter(zoneTrees.first));
    await widgetTester.pump();

    expect(hoveredZone, 0);

    await gesture.moveTo(Offset.infinite);
    await widgetTester.pump();

    expect(hoveredZone, isNull);

    await widgetTester.tap(zoneTrees.first);
    await widgetTester.pumpAndSettle();

    expect(selectedZone, 0);

    var maxVelField =
        find.widgetWithText(NumberTextField, 'Max Velocity (M/S)');
    var maxAccelField =
        find.widgetWithText(NumberTextField, 'Max Acceleration (M/S²)');
    var maxAngVelField =
        find.widgetWithText(NumberTextField, 'Max Angular Velocity (Deg/S)');
    var maxAngAccelField = find.widgetWithText(
        NumberTextField, 'Max Angular Acceleration (Deg/S²)');
    var sliders = find.byType(Slider);

    expect(maxVelField, findsOneWidget);
    expect(maxAccelField, findsOneWidget);
    expect(maxAngVelField, findsOneWidget);
    expect(maxAngAccelField, findsOneWidget);
    expect(sliders, findsNWidgets(2));
  });
}
