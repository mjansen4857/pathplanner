import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  test('Constructor functions', () {
    RotationTarget t = RotationTarget(1.0, const Rotation2d(2.0));

    expect(t.waypointRelativePos, 1.0);
    expect(t.rotation.radians, 2.0);
  });

  test('toJson/fromJson interoperability', () {
    RotationTarget t = RotationTarget(1.0, const Rotation2d(2.0));

    Map<String, dynamic> json = t.toJson();
    RotationTarget fromJson = RotationTarget.fromJson(json);

    expect(fromJson, t);
  });

  test('Proper cloning', () {
    RotationTarget t = RotationTarget(1.0, const Rotation2d(2.0));
    RotationTarget cloned = t.clone();

    expect(cloned, t);

    cloned.waypointRelativePos = 5.0;

    expect(t, isNot(cloned));
  });

  test('equals/hashCode', () {
    RotationTarget t1 = RotationTarget(1.0, const Rotation2d(2.0));
    RotationTarget t2 = RotationTarget(1.0, const Rotation2d(2.0));
    RotationTarget t3 = RotationTarget(1.5, const Rotation2d(2.5));

    expect(t2, t1);
    expect(t3, isNot(t1));

    expect(t2.hashCode, t1.hashCode);
    expect(t3.hashCode, isNot(t1.hashCode));
  });
}
