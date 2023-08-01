import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/services/simulator/chassis_speeds.dart';
import 'package:pathplanner/services/simulator/chassis_speeds_limiter.dart';

const num epsilon = 0.01;

void main() {
  test('limit speeds', () {
    ChassisSpeedsLimiter limiter = ChassisSpeedsLimiter(
      translationLimit: 2.0,
      rotationLimit: 5.0,
    );

    var speeds =
        limiter.calculate(ChassisSpeeds(vx: 2.0, vy: 2.0, omega: 5.0), 0.1);

    expect(speeds.vx, closeTo(0.14, epsilon));
    expect(speeds.vy, closeTo(0.14, epsilon));
    expect(speeds.omega, closeTo(0.5, epsilon));

    speeds =
        limiter.calculate(ChassisSpeeds(vx: 2.0, vy: 2.0, omega: 5.0), 2.0);

    expect(speeds.vx, closeTo(2.0, epsilon));
    expect(speeds.vy, closeTo(2.0, epsilon));
    expect(speeds.omega, closeTo(5.0, epsilon));

    speeds =
        limiter.calculate(ChassisSpeeds(vx: -2.0, vy: 2.0, omega: -5.0), 0.5);

    expect(speeds.vx, closeTo(1.0, epsilon));
    expect(speeds.vy, closeTo(2.0, epsilon));
    expect(speeds.omega, closeTo(2.5, epsilon));

    limiter.setRateLimits(0.1, 0.1);

    speeds = limiter.calculate(ChassisSpeeds(vx: 0, vy: 0, omega: 0), 2.0);

    expect(speeds.vx, closeTo(0.91, epsilon));
    expect(speeds.vy, closeTo(1.82, epsilon));
    expect(speeds.omega, closeTo(2.3, epsilon));

    speeds = limiter.calculate(ChassisSpeeds(vx: 0, vy: 0, omega: 0), 2.0);

    expect(speeds.vx, closeTo(0.82, epsilon));
    expect(speeds.vy, closeTo(1.64, epsilon));
    expect(speeds.omega, closeTo(2.1, epsilon));

    speeds = limiter.calculate(ChassisSpeeds(vx: 0, vy: 0, omega: 0), 2.0);

    expect(speeds.vx, closeTo(0.73, epsilon));
    expect(speeds.vy, closeTo(1.46, epsilon));
    expect(speeds.omega, closeTo(1.9, epsilon));

    speeds = limiter.calculate(ChassisSpeeds(vx: 0, vy: 0, omega: 0), 50.0);

    expect(speeds.vx, closeTo(0, epsilon));
    expect(speeds.vy, closeTo(0, epsilon));
    expect(speeds.omega, closeTo(0, epsilon));
  });
}
