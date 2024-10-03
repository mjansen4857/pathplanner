import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/point_towards_zone.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  test('Constructor functions', () {
    PointTowardsZone zone = PointTowardsZone(
      fieldPosition: const Translation2d(1.0, 1.0),
      rotationOffset: Rotation2d.fromDegrees(90),
      minWaypointRelativePos: 1.0,
      maxWaypointRelativePos: 2.0,
      name: 'test zone',
    );

    expect(zone.fieldPosition.x, 1.0);
    expect(zone.fieldPosition.y, 1.0);
    expect(zone.rotationOffset.degrees, closeTo(90, 0.001));
    expect(zone.minWaypointRelativePos, 1.0);
    expect(zone.maxWaypointRelativePos, 2.0);
    expect(zone.name, 'test zone');
  });

  test('toJson/fromJson interoperability', () {
    PointTowardsZone zone = PointTowardsZone(
      fieldPosition: const Translation2d(1.0, 1.0),
      rotationOffset: Rotation2d.fromDegrees(90),
      minWaypointRelativePos: 1.0,
      maxWaypointRelativePos: 2.0,
      name: 'test zone',
    );

    Map<String, dynamic> zoneJson = zone.toJson();
    PointTowardsZone fromJson = PointTowardsZone.fromJson(zoneJson);

    expect(fromJson, zone);
  });

  test('Proper cloning', () {
    PointTowardsZone zone = PointTowardsZone();
    PointTowardsZone cloned = zone.clone();

    expect(cloned, zone);
    expect(cloned.hashCode, zone.hashCode);

    cloned.minWaypointRelativePos = 0.7;
    cloned.rotationOffset = Rotation2d.fromDegrees(45);

    expect(zone, isNot(cloned));
    expect(zone.hashCode, isNot(cloned.hashCode));
  });
}
