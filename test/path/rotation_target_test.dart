import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/rotation_target.dart';

void main() {
  test('Constructor functions', () {
    RotationTarget t = RotationTarget(
        waypointRelativePos: 1.0, rotationDegrees: 5.0, rotateFast: true);

    expect(t.waypointRelativePos, 1.0);
    expect(t.rotationDegrees, 5.0);
    expect(t.rotateFast, true);
  });

  test('toJson/fromJson interoperability', () {
    RotationTarget t =
        RotationTarget(waypointRelativePos: 1.0, rotationDegrees: 5.0);

    Map<String, dynamic> json = t.toJson();
    RotationTarget fromJson = RotationTarget.fromJson(json);

    expect(fromJson, t);
  });

  test('Proper cloning', () {
    RotationTarget t = RotationTarget();
    RotationTarget cloned = t.clone();

    expect(cloned, t);

    cloned.rotationDegrees = 5.0;

    expect(t, isNot(cloned));
  });

  test('equals/hashCode', () {
    RotationTarget t1 =
        RotationTarget(waypointRelativePos: 1.0, rotationDegrees: 5.0);
    RotationTarget t2 =
        RotationTarget(waypointRelativePos: 1.0, rotationDegrees: 5.0);
    RotationTarget t3 = RotationTarget();

    expect(t2, t1);
    expect(t3, isNot(t1));

    expect(t2.hashCode, t1.hashCode);
    expect(t3.hashCode, isNot(t1.hashCode));
  });
}
