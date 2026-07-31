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
        () => TranslationWaypoint(
          position: const Translation2d(double.nan, 0),
        ),
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
