import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/path_constraints.dart';

void main() {
  test('Constructor functions', () {
    PathConstraints constraints = PathConstraints(
      maxVelocity: 1.0,
      maxAcceleration: 2.0,
      maxAngularVelocity: 3.0,
      maxAngularAcceleration: 4.0,
    );

    expect(constraints.maxVelocity, 1.0);
    expect(constraints.maxAcceleration, 2.0);
    expect(constraints.maxAngularVelocity, 3.0);
    expect(constraints.maxAngularAcceleration, 4.0);
  });

  test('toJson/fromJson interoperability', () {
    PathConstraints constraints = PathConstraints(
      maxVelocity: 1.0,
      maxAcceleration: 2.0,
      maxAngularVelocity: 3.0,
      maxAngularAcceleration: 4.0,
    );

    Map<String, dynamic> json = constraints.toJson();
    PathConstraints fromJson = PathConstraints.fromJson(json);

    expect(fromJson, constraints);
  });

  test('Proper cloning', () {
    PathConstraints constraints = PathConstraints();
    PathConstraints cloned = constraints.clone();

    expect(cloned, constraints);

    cloned.maxVelocity = 7.2;

    expect(constraints, isNot(cloned));
  });

  test('equals/hashCode', () {
    PathConstraints constraints1 = PathConstraints();
    PathConstraints constraints2 = PathConstraints();
    PathConstraints constraints3 = PathConstraints(maxVelocity: 1.0);

    expect(constraints2, constraints1);
    expect(constraints3, isNot(constraints1));

    expect(constraints2.hashCode, constraints1.hashCode);
    expect(constraints3.hashCode, isNot(constraints1.hashCode));
  });
}
