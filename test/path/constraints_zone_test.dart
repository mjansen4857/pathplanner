import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/path_constraints.dart';

void main() {
  test('Constructor functions', () {
    PathConstraints constraints = PathConstraints(
      maxVelocity: 1.0,
      maxAcceleration: 2.0,
      maxAngularVelocity: 3.0,
      maxAngularAcceleration: 4.0,
    );

    ConstraintsZone zone = ConstraintsZone(
      minWaypointRelativePos: 1.5,
      maxWaypointRelativePos: 2.1,
      name: 'test zone',
      constraints: constraints,
    );

    expect(zone.minWaypointRelativePos, 1.5);
    expect(zone.maxWaypointRelativePos, 2.1);
    expect(zone.name, 'test zone');
    expect(zone.constraints, constraints);
  });

  test('toJson/fromJson interoperability', () {
    ConstraintsZone zone = ConstraintsZone(
      minWaypointRelativePos: 1.5,
      maxWaypointRelativePos: 2.1,
      name: 'test zone',
      constraints: PathConstraints(
        maxVelocity: 1.0,
        maxAcceleration: 2.0,
        maxAngularVelocity: 3.0,
        maxAngularAcceleration: 4.0,
      ),
    );

    Map<String, dynamic> zoneJson = zone.toJson();
    ConstraintsZone fromJson = ConstraintsZone.fromJson(zoneJson);

    expect(fromJson, zone);
  });

  test('Proper cloning', () {
    ConstraintsZone zone = ConstraintsZone.defaultZone();
    ConstraintsZone cloned = zone.clone();

    expect(cloned, zone);

    cloned.minWaypointRelativePos = 0.7;
    cloned.constraints.maxVelocity = 8.2;

    expect(zone, isNot(cloned));
  });

  test('equals/hashCode', () {
    ConstraintsZone zone1 = ConstraintsZone(
      minWaypointRelativePos: 1.5,
      maxWaypointRelativePos: 2.1,
      name: 'zone',
      constraints: PathConstraints(),
    );
    ConstraintsZone zone2 = ConstraintsZone(
      minWaypointRelativePos: 1.5,
      maxWaypointRelativePos: 2.1,
      name: 'zone',
      constraints: PathConstraints(),
    );
    ConstraintsZone zone3 = ConstraintsZone(
      minWaypointRelativePos: 1.8,
      maxWaypointRelativePos: 2.5,
      name: 'zone3',
      constraints: PathConstraints(),
    );

    expect(zone2, zone1);
    expect(zone3, isNot(zone1));

    expect(zone2.hashCode, zone1.hashCode);
    expect(zone3.hashCode, isNot(zone1.hashCode));
  });
}
