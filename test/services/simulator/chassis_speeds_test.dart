import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/services/simulator/chassis_speeds.dart';

void main() {
  test('equals/hashCode', () {
    ChassisSpeeds speeds1 = ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
    ChassisSpeeds speeds2 = ChassisSpeeds(vx: 1.0, vy: 2.0, omega: 3.0);
    ChassisSpeeds speeds3 = ChassisSpeeds(vx: 1.5, vy: 2.0, omega: 2.0);

    expect(speeds2, speeds1);
    expect(speeds3, isNot(speeds1));

    expect(speeds2.hashCode, speeds1.hashCode);
    expect(speeds3.hashCode, isNot(speeds1.hashCode));
  });
}
