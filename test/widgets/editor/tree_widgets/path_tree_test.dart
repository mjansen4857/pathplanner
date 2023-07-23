import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';

void main() {
  testWidgets('test path tree', (widgetTester) async {
    PathPlannerPath path = PathPlannerPath(
      name: 'test',
      waypoints: PathPlannerPath.defaultPath().waypoints,
      globalConstraints: PathConstraints(
        maxVelocity: 10.11,
        maxAcceleration: 10.22,
        maxAngularVelocity: 10.33,
        maxAngularAcceleration: 10.44,
      ),
      goalEndState: GoalEndState(
        velocity: 11.11,
        rotation: 11.22,
      ),
      constraintZones: [
        ConstraintsZone(
          minWaypointRelativePos: 0.4,
          maxWaypointRelativePos: 0.6,
          constraints: PathConstraints(
            maxVelocity: 12.11,
            maxAcceleration: 12.22,
            maxAngularVelocity: 12.33,
            maxAngularAcceleration: 12.44,
          ),
        ),
        ConstraintsZone(
          minWaypointRelativePos: 1.4,
          maxWaypointRelativePos: 1.6,
          constraints: PathConstraints(
            maxVelocity: 13.11,
            maxAcceleration: 13.22,
            maxAngularVelocity: 13.33,
            maxAngularAcceleration: 13.44,
          ),
        ),
      ],
      rotationTargets: [
        RotationTarget(
          waypointRelativePos: 1.8,
          rotationDegrees: 45,
        ),
        RotationTarget(
          waypointRelativePos: 1.9,
          rotationDegrees: -45,
        ),
      ],
      eventMarkers: [
        EventMarker(
          waypointRelativePos: 1.0,
          command: WaitCommand(waitTime: 14.11),
        ),
        EventMarker(
          waypointRelativePos: 1.1,
          command: WaitCommand(waitTime: 15.11),
        ),
      ],
    );

    path.waypointsExpanded = true;
    path.goalEndStateExpanded = true;
    path.eventMarkersExpanded = true;
    path.constraintZonesExpanded = true;
    path.rotationTargetsExpanded = true;
    path.globalConstraintsExpanded = true;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
        ),
      ),
    ));

    // Waypoints tree populated
    var waypointCards = find.descendant(
        of: find.widgetWithText(TreeCardNode, 'Waypoints'),
        matching: find.byType(TreeCardNode));
    expect(waypointCards, findsNWidgets(3));

    // Constraint zones tree populated
    var zoneCards = find.descendant(
        of: find.widgetWithText(TreeCardNode, 'Constraint Zones'),
        matching: find.byType(TreeCardNode));
    expect(zoneCards, findsNWidgets(2));

    // Rotation targets tree populated
    var targetCards = find.descendant(
        of: find.widgetWithText(TreeCardNode, 'Rotation Targets'),
        matching: find.byType(TreeCardNode));
    expect(targetCards, findsNWidgets(2));

    // Event markers tree populated
    var markerCards = find.descendant(
        of: find.widgetWithText(TreeCardNode, 'Event Markers'),
        matching: find.byType(TreeCardNode));
    expect(markerCards, findsNWidgets(2));
  });
}
