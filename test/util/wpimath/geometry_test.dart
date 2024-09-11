import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

const num epsilon = 0.001;

void main() {
  group('Pose2d', () {
    test('constructor', () {
      var translation = const Translation2d(x: 3.0, y: 4.0);
      var rotation = Rotation2d.fromDegrees(45);
      var pose = Pose2d(translation, rotation);
      expect(pose.translation, equals(translation));
      expect(pose.rotation, equals(rotation));
    });

    test('interpolate', () {
      var t1 = const Translation2d(x: 1.0, y: 2.0);
      var r1 = Rotation2d.fromDegrees(0);
      var p1 = Pose2d(t1, r1);

      var t2 = const Translation2d(x: 3.0, y: 4.0);
      var r2 = Rotation2d.fromDegrees(90);
      var p2 = Pose2d(t2, r2);

      var result = p1.interpolate(p2, 0.5);

      expect(result.translation.x, closeTo(2.0, epsilon));
      expect(result.translation.y, closeTo(3.0, epsilon));
      expect(result.rotation.getDegrees(), closeTo(45.0, epsilon));
    });

    test('clone', () {
      var translation = const Translation2d(x: 3.0, y: 4.0);
      var rotation = Rotation2d.fromDegrees(45);
      var pose = Pose2d(translation, rotation);
      var clone = pose.clone();
      expect(clone.translation, equals(pose.translation));
      expect(clone.rotation, equals(pose.rotation));
      expect(identical(clone, pose), isFalse);
    });
  });

  group('Translation2d', () {
    test('default constructor', () {
      var t = const Translation2d();
      expect(t.x, equals(0.0));
      expect(t.y, equals(0.0));
    });

    test('constructor with values', () {
      var t = const Translation2d(x: 3.0, y: 4.0);
      expect(t.x, equals(3.0));
      expect(t.y, equals(4.0));
    });

    test('constructor from angle', () {
      var angle = Rotation2d.fromDegrees(-45);
      var t = Translation2d.fromAngle(5.0, angle);
      expect(t.x, closeTo(3.536, epsilon));
      expect(t.y, closeTo(-3.536, epsilon));
    });

    test('addition operator', () {
      var t1 = const Translation2d(x: 3.0, y: 4.0);
      var t2 = const Translation2d(x: 1.0, y: 2.0);
      var result = t1 + t2;
      expect(result.x, equals(4.0));
      expect(result.y, equals(6.0));
    });

    test('subtraction operator', () {
      var t1 = const Translation2d(x: 3.0, y: 4.0);
      var t2 = const Translation2d(x: 1.0, y: 2.0);
      var result = t1 - t2;
      expect(result.x, equals(2.0));
      expect(result.y, equals(2.0));
    });

    test('multiplication operator', () {
      var t1 = const Translation2d(x: 3.0, y: 4.0);
      var result = t1 * 2.0;
      expect(result.x, equals(6.0));
      expect(result.y, equals(8.0));
    });

    test('division operator', () {
      var t1 = const Translation2d(x: 3.0, y: 4.0);
      var result = t1 / 2.0;
      expect(result.x, equals(1.5));
      expect(result.y, equals(2.0));
    });

    test('getDistance', () {
      var t1 = const Translation2d(x: 3.0, y: 4.0);
      var t2 = const Translation2d(x: 1.0, y: 2.0);
      var distance = t1.getDistance(t2);
      expect(distance, closeTo(2.828, epsilon));
    });

    test('getNorm', () {
      var t = const Translation2d(x: 3.0, y: 4.0);
      var norm = t.getNorm();
      expect(norm, equals(5.0));
    });

    test('getAngle', () {
      var t = const Translation2d(x: 3.0, y: 4.0);
      var angle = t.getAngle();
      expect(angle.getDegrees(), closeTo(53.130, epsilon));
    });

    test('rotateBy', () {
      var t = const Translation2d(x: 1.0, y: 0.0);
      var angle = Rotation2d.fromDegrees(90);
      var result = t.rotateBy(angle);
      expect(result.x, closeTo(0.0, epsilon));
      expect(result.y, closeTo(1.0, epsilon));
    });

    test('interpolate', () {
      var t1 = const Translation2d(x: 1.0, y: 2.0);
      var t2 = const Translation2d(x: 3.0, y: 4.0);
      var result = t1.interpolate(t2, 0.5);
      expect(result.x, closeTo(2.0, epsilon));
      expect(result.y, closeTo(3.0, epsilon));
    });

    test('asPoint', () {
      var t1 = const Translation2d(x: 1.0, y: 2.0);
      var p1 = const Point(1.0, 2.0);
      expect(t1.asPoint().x, closeTo(p1.x, epsilon));
      expect(t1.asPoint().y, closeTo(p1.y, epsilon));
    });

    test('clone', () {
      var t = const Translation2d(x: 3.0, y: 4.0);
      var clone = t.clone();
      expect(clone, equals(t));
      expect(identical(clone, t), isFalse);
    });

    test('== operator', () {
      var t1 = const Translation2d(x: 3.0, y: 4.0);
      var t2 = const Translation2d(x: 3.0, y: 4.0);
      var t3 = const Translation2d(x: 4.0, y: 3.0);
      expect(t1 == t2, isTrue);
      expect(t1 == t3, isFalse);
    });

    test('hashCode', () {
      var t1 = const Translation2d(x: 3.0, y: 4.0);
      var t2 = const Translation2d(x: 3.0, y: 4.0);
      var t3 = const Translation2d(x: 4.0, y: 3.0);
      expect(t1.hashCode, equals(t2.hashCode));
      expect(t1.hashCode, isNot(equals(t3.hashCode)));
    });

    test('toString', () {
      var t = const Translation2d(x: 3.0, y: 4.0);
      expect(t.toString(), equals('Translation2d(X: 3.00, Y: 4.00)'));
    });
  });

  group('Rotation2d', () {
    test('fromRadians', () {
      Rotation2d rot1 = Rotation2d.fromRadians(pi);
      Rotation2d rot2 = Rotation2d.fromRadians(pi / 2);
      Rotation2d rot3 = Rotation2d.fromRadians(-pi / 4);

      expect(rot1.getRadians(), closeTo(pi, epsilon));
      expect(rot2.getRadians(), closeTo(pi / 2, epsilon));
      expect(rot3.getRadians(), closeTo(-pi / 4, epsilon));

      expect(rot1.getDegrees(), closeTo(180, epsilon));
      expect(rot2.getDegrees(), closeTo(90, epsilon));
      expect(rot3.getDegrees(), closeTo(-45, epsilon));

      expect(rot1.getRotations(), closeTo(0.5, epsilon));
      expect(rot2.getRotations(), closeTo(0.25, epsilon));
      expect(rot3.getRotations(), closeTo(-0.125, epsilon));
    });

    test('fromDegrees', () {
      Rotation2d rot1 = Rotation2d.fromDegrees(180);
      Rotation2d rot2 = Rotation2d.fromDegrees(90);
      Rotation2d rot3 = Rotation2d.fromDegrees(-45);

      expect(rot1.getRadians(), closeTo(pi, epsilon));
      expect(rot2.getRadians(), closeTo(pi / 2, epsilon));
      expect(rot3.getRadians(), closeTo(-pi / 4, epsilon));

      expect(rot1.getDegrees(), closeTo(180, epsilon));
      expect(rot2.getDegrees(), closeTo(90, epsilon));
      expect(rot3.getDegrees(), closeTo(-45, epsilon));

      expect(rot1.getRotations(), closeTo(0.5, epsilon));
      expect(rot2.getRotations(), closeTo(0.25, epsilon));
      expect(rot3.getRotations(), closeTo(-0.125, epsilon));
    });

    test('fromRotations', () {
      Rotation2d rot1 = Rotation2d.fromRotations(0.5);
      Rotation2d rot2 = Rotation2d.fromRotations(0.25);
      Rotation2d rot3 = Rotation2d.fromRotations(-0.125);

      expect(rot1.getRadians(), closeTo(pi, epsilon));
      expect(rot2.getRadians(), closeTo(pi / 2, epsilon));
      expect(rot3.getRadians(), closeTo(-pi / 4, epsilon));

      expect(rot1.getDegrees(), closeTo(180, epsilon));
      expect(rot2.getDegrees(), closeTo(90, epsilon));
      expect(rot3.getDegrees(), closeTo(-45, epsilon));

      expect(rot1.getRotations(), closeTo(0.5, epsilon));
      expect(rot2.getRotations(), closeTo(0.25, epsilon));
      expect(rot3.getRotations(), closeTo(-0.125, epsilon));
    });
  });

  test('cosine', () {
    Rotation2d rot1 = Rotation2d.fromRadians(pi);
    Rotation2d rot2 = Rotation2d.fromRadians(pi / 2);
    Rotation2d rot3 = Rotation2d.fromRadians(-pi / 4);

    expect(rot1.getCos(), closeTo(-1.0, epsilon));
    expect(rot2.getCos(), closeTo(0.0, epsilon));
    expect(rot3.getCos(), closeTo(0.707, epsilon));
  });

  test('sine', () {
    Rotation2d rot1 = Rotation2d.fromRadians(pi);
    Rotation2d rot2 = Rotation2d.fromRadians(pi / 2);
    Rotation2d rot3 = Rotation2d.fromRadians(-pi / 4);

    expect(rot1.getSin(), closeTo(0.0, epsilon));
    expect(rot2.getSin(), closeTo(1.0, epsilon));
    expect(rot3.getSin(), closeTo(-0.707, epsilon));
  });

  test('tangent', () {
    Rotation2d rot1 = Rotation2d.fromRadians(pi);
    Rotation2d rot2 = Rotation2d.fromRadians(pi / 3);
    Rotation2d rot3 = Rotation2d.fromRadians(-pi / 4);

    expect(rot1.getTan(), closeTo(0.0, epsilon));
    expect(rot2.getTan(), closeTo(1.732, epsilon));
    expect(rot3.getTan(), closeTo(-1.0, epsilon));
  });

  test('plus', () {
    Rotation2d a = Rotation2d.fromDegrees(90);
    Rotation2d b = Rotation2d.fromDegrees(30);
    Rotation2d c = Rotation2d.fromDegrees(360);

    Rotation2d ab = a + b;
    Rotation2d ba = b + a;
    Rotation2d ac = a + c;

    expect(ab.getDegrees(), closeTo(120.0, epsilon));
    expect(ba.getDegrees(), closeTo(120.0, epsilon));
    expect(ac.getDegrees(), closeTo(90.0, epsilon));
  });

  test('minus', () {
    Rotation2d a = Rotation2d.fromDegrees(90);
    Rotation2d b = Rotation2d.fromDegrees(30);
    Rotation2d c = Rotation2d.fromDegrees(360);

    Rotation2d ab = a - b;
    Rotation2d ba = b - a;
    Rotation2d ac = a - c;

    expect(ab.getDegrees(), closeTo(60.0, epsilon));
    expect(ba.getDegrees(), closeTo(-60.0, epsilon));
    expect(ac.getDegrees(), closeTo(90.0, epsilon));
  });

  test('times', () {
    Rotation2d a = Rotation2d.fromDegrees(90) * 0.5;
    Rotation2d b = Rotation2d.fromDegrees(30) * 1.0;
    Rotation2d c = Rotation2d.fromDegrees(360) * 2.0;

    expect(a.getDegrees(), closeTo(45.0, epsilon));
    expect(b.getDegrees(), closeTo(30.0, epsilon));
    expect(c.getDegrees(), closeTo(720.0, epsilon));
  });

  test('div', () {
    Rotation2d a = Rotation2d.fromDegrees(90) / 0.5;
    Rotation2d b = Rotation2d.fromDegrees(30) / 1.0;
    Rotation2d c = Rotation2d.fromDegrees(360) / 2.0;

    expect(a.getDegrees(), closeTo(180.0, epsilon));
    expect(b.getDegrees(), closeTo(30.0, epsilon));
    expect(c.getDegrees(), closeTo(180.0, epsilon));
  });

  test('interpolate', () {
    Rotation2d a =
        Rotation2d.fromDegrees(0).interpolate(Rotation2d.fromDegrees(90), 0.5);
    Rotation2d b = Rotation2d.fromDegrees(-30)
        .interpolate(Rotation2d.fromDegrees(-90), 0.5);
    Rotation2d c = Rotation2d.fromDegrees(120)
        .interpolate(Rotation2d.fromDegrees(-120), 0.2);

    expect(a.getDegrees(), closeTo(45.0, epsilon));
    expect(b.getDegrees(), closeTo(-60.0, epsilon));
    expect(c.getDegrees(), closeTo(144.0, epsilon));
  });

  test('clone', () {
    Rotation2d a = Rotation2d.fromDegrees(67);
    Rotation2d b = a.clone();

    expect(a.getDegrees(), closeTo(67.0, epsilon));
    expect(b.getDegrees(), closeTo(67.0, epsilon));
  });

  test('equals/hashcode', () {
    Rotation2d a = Rotation2d.fromDegrees(67);
    Rotation2d b = Rotation2d.fromDegrees(67);
    Rotation2d c = Rotation2d.fromDegrees(-25);

    expect(a == b, isTrue);
    expect(b == a, isTrue);
    expect(a == c, isFalse);
    expect(c == b, isFalse);

    expect(a.hashCode == b.hashCode, isTrue);
    expect(a.hashCode == c.hashCode, isFalse);
  });

  test('toString', () {
    Rotation2d a = Rotation2d.fromDegrees(180.0);

    expect(a.toString(), 'Rotation2d(Rads: 3.14, Deg: 180.00)');
  });
}
