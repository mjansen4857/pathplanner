import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  group('Path 2 waypoints', () {
    test('translation waypoint round trips without handoff state', () {
      final waypoint = TranslationWaypoint(
        position: const Translation2d(1.25, 2.5),
        maxVelocity: 3.0,
        maxAngularVelocity: 240,
        maxAngularAcceleration: 480,
      );

      final json = waypoint.toJson();
      expect(json, isNot(contains('handoffDistance')));
      expect(Waypoint.fromJson(json), waypoint);
    });

    test('pose waypoint round trips and clones deeply', () {
      final waypoint = PoseWaypoint(
        position: const Translation2d(3, 4),
        rotation: Rotation2d.fromDegrees(90),
        maxVelocity: 2,
      );
      final clone = waypoint.clone();

      clone.move(8, 9);

      expect(Waypoint.fromJson(waypoint.toJson()), waypoint);
      expect(waypoint.position, const Translation2d(3, 4));
      expect(clone.position, const Translation2d(8, 9));
    });

    test('point-towards waypoint round trips with optional defaults', () {
      final waypoint = Waypoint.fromJson({
        'type': 'pointTowards',
        'position': {'x': 1.25, 'y': -2.5},
        'targetPosition': {'x': -3.0, 'y': 4.5},
      }) as PointTowardsWaypoint;

      expect(waypoint.targetPosition, const Translation2d(-3, 4.5));
      expect(waypoint.unprofiled, isFalse);
      expect(waypoint.inheritTargetFromParent, isFalse);
      expect(Waypoint.fromJson(waypoint.toJson()), waypoint);
      expect(waypoint.toJson(), {
        'type': 'pointTowards',
        'position': {'x': 1.25, 'y': -2.5},
        'targetPosition': {'x': -3.0, 'y': 4.5},
        'unprofiled': false,
        'inheritTargetFromParent': false,
        'maxVelocity': Waypoint.defaultMaxVelocity,
        'maxAngularVelocity': Waypoint.defaultMaxAngularVelocity,
        'maxAngularAcceleration': Waypoint.defaultMaxAngularAcceleration,
      });
    });

    test('point-towards cloning and conversion retain the right state', () {
      final original = PointTowardsWaypoint(
        position: const Translation2d(1, 2),
        targetPosition: const Translation2d(3, 4),
        unprofiled: true,
        inheritTargetFromParent: true,
        maxVelocity: 1.5,
        maxAngularVelocity: 200,
        maxAngularAcceleration: 300,
      );

      final clone = original.clone()..moveTarget(8, 9);
      final sameType = original.convertedTo(WaypointType.pointTowards);
      final converted = original.convertedTo(WaypointType.translation);
      final newPoint = converted.convertedTo(WaypointType.pointTowards);

      expect(original.targetPosition, const Translation2d(3, 4));
      expect(clone.targetPosition, const Translation2d(8, 9));
      expect(sameType, original);
      expect(sameType, isNot(same(original)));
      expect(converted, isA<TranslationWaypoint>());
      expect(converted.maxVelocity, 1.5);
      expect(converted.maxAngularVelocity, 200);
      expect(converted.maxAngularAcceleration, 300);
      expect(
        (newPoint as PointTowardsWaypoint).targetPosition,
        PointTowardsWaypoint.defaultTargetPosition,
      );
      expect(newPoint.unprofiled, isFalse);
      expect(newPoint.inheritTargetFromParent, isFalse);
    });

    test('waypoint type conversion retains all motion limits', () {
      final translation = TranslationWaypoint(
        position: const Translation2d(1, 2),
        maxVelocity: 1.5,
        maxAngularVelocity: 200,
        maxAngularAcceleration: 300,
      );

      final pose = translation.withRotation(Rotation2d.fromDegrees(30));
      final restored = pose.withRotation(null);

      expect(pose, isA<PoseWaypoint>());
      expect(restored, isA<TranslationWaypoint>());
      expect(restored.maxVelocity, 1.5);
      expect(restored.maxAngularVelocity, 200);
      expect(restored.maxAngularAcceleration, 300);
    });

    test('invalid numeric values and unknown types are rejected', () {
      expect(
        () => TranslationWaypoint(position: const Translation2d(double.nan, 0)),
        throwsArgumentError,
      );
      expect(
        () => TranslationWaypoint(
          position: const Translation2d(),
          maxVelocity: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => Waypoint.fromJson({
          'type': 'translation',
          'position': {'x': 0, 'y': 0},
          'maxAngularVelocity': double.infinity,
        }),
        throwsFormatException,
      );
      expect(
        () => PointTowardsWaypoint(
          position: const Translation2d(),
          targetPosition: const Translation2d(double.infinity, 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => Waypoint.fromJson({
          'type': 'pointTowards',
          'position': {'x': 0, 'y': 0},
          'targetPosition': {'x': double.nan, 'y': 0},
        }),
        throwsFormatException,
      );
      expect(
        () => Waypoint.fromJson({
          'type': 'pointTowards',
          'position': {'x': 0, 'y': 0},
          'targetPosition': {'x': 1, 'y': 2},
          'unprofiled': 'yes',
        }),
        throwsFormatException,
      );
      expect(
        () => Waypoint.fromJson({
          'type': 'mystery',
          'position': {'x': 0, 'y': 0},
        }),
        throwsFormatException,
      );
    });

    test('dragging changes only while active', () {
      final waypoint = TranslationWaypoint(position: const Translation2d(1, 1));

      waypoint.dragUpdate(2, 2);
      expect(waypoint.position, const Translation2d(1, 1));
      expect(waypoint.startDragging(1, 1, 0.2), isTrue);
      waypoint.dragUpdate(2, 3);
      expect(waypoint.position, const Translation2d(2, 3));
      waypoint.stopDragging();
      waypoint.dragUpdate(4, 5);
      expect(waypoint.position, const Translation2d(2, 3));
    });
  });
}
