import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

const num epsilon = 0.001;

void main() {
  group('Pose2d', () {
    test('constructor', () {
      var translation = const Translation2d(3.0, 4.0);
      var rotation = Rotation2d.fromDegrees(45);
      var pose = Pose2d(translation, rotation);
      expect(pose.translation, equals(translation));
      expect(pose.rotation, equals(rotation));
    });

    test('interpolate', () {
      var t1 = const Translation2d(1.0, 2.0);
      var r1 = Rotation2d.fromDegrees(0);
      var p1 = Pose2d(t1, r1);

      var t2 = const Translation2d(3.0, 4.0);
      var r2 = Rotation2d.fromDegrees(90);
      var p2 = Pose2d(t2, r2);

      var result = p1.interpolate(p2, 0.5);

      expect(result.translation.x, closeTo(2.0, epsilon));
      expect(result.translation.y, closeTo(3.0, epsilon));
      expect(result.rotation.degrees, closeTo(45.0, epsilon));
    });

    group('struct decoding', () {
      test('single pose', () {
        List<int> rawBytes = [
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x14,
          0x40,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x14,
          0x40,
          0x18,
          0x2d,
          0x44,
          0x54,
          0xfb,
          0x21,
          0x09,
          0x40
        ];
        Uint8List data = Uint8List.fromList(rawBytes);

        Pose2d pose = Pose2d.fromBytes(data);

        expect(pose.x, closeTo(5.0, epsilon));
        expect(pose.y, closeTo(5.0, epsilon));
        expect(pose.rotation.radians, closeTo(pi, epsilon));
      });

      test('list of poses', () {
        List<int> rawBytes = [
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x14,
          0x40,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x14,
          0x40,
          0x18,
          0x2d,
          0x44,
          0x54,
          0xfb,
          0x21,
          0x09,
          0x40,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x14,
          0x40,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x14,
          0x40,
          0x18,
          0x2d,
          0x44,
          0x54,
          0xfb,
          0x21,
          0x09,
          0x40
        ];
        Uint8List data = Uint8List.fromList(rawBytes);

        final poses = Pose2d.listFromBytes(data);

        expect(poses.length, 2);

        expect(poses[0].x, closeTo(5.0, epsilon));
        expect(poses[0].y, closeTo(5.0, epsilon));
        expect(poses[0].rotation.radians, closeTo(pi, epsilon));
        expect(poses[1].x, closeTo(5.0, epsilon));
        expect(poses[1].y, closeTo(5.0, epsilon));
        expect(poses[1].rotation.radians, closeTo(pi, epsilon));
      });
    });
  });

  group('Translation2d', () {
    test('default constructor', () {
      var t = const Translation2d();
      expect(t.x, equals(0.0));
      expect(t.y, equals(0.0));
    });

    test('constructor with values', () {
      var t = const Translation2d(3.0, 4.0);
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
      var t1 = const Translation2d(3.0, 4.0);
      var t2 = const Translation2d(1.0, 2.0);
      var result = t1 + t2;
      expect(result.x, equals(4.0));
      expect(result.y, equals(6.0));
    });

    test('subtraction operator', () {
      var t1 = const Translation2d(3.0, 4.0);
      var t2 = const Translation2d(1.0, 2.0);
      var result = t1 - t2;
      expect(result.x, equals(2.0));
      expect(result.y, equals(2.0));
    });

    test('multiplication operator', () {
      var t1 = const Translation2d(3.0, 4.0);
      var result = t1 * 2.0;
      expect(result.x, equals(6.0));
      expect(result.y, equals(8.0));
    });

    test('division operator', () {
      var t1 = const Translation2d(3.0, 4.0);
      var result = t1 / 2.0;
      expect(result.x, equals(1.5));
      expect(result.y, equals(2.0));
    });

    test('getDistance', () {
      var t1 = const Translation2d(3.0, 4.0);
      var t2 = const Translation2d(1.0, 2.0);
      var distance = t1.getDistance(t2);
      expect(distance, closeTo(2.828, epsilon));
    });

    test('getNorm', () {
      var t = const Translation2d(3.0, 4.0);
      var norm = t.norm;
      expect(norm, equals(5.0));
    });

    test('getAngle', () {
      var t = const Translation2d(3.0, 4.0);
      var angle = t.angle;
      expect(angle.degrees, closeTo(53.130, epsilon));
    });

    test('rotateBy', () {
      var t = const Translation2d(1.0, 0.0);
      var angle = Rotation2d.fromDegrees(90);
      var result = t.rotateBy(angle);
      expect(result.x, closeTo(0.0, epsilon));
      expect(result.y, closeTo(1.0, epsilon));
    });

    test('interpolate', () {
      var t1 = const Translation2d(1.0, 2.0);
      var t2 = const Translation2d(3.0, 4.0);
      var result = t1.interpolate(t2, 0.5);
      expect(result.x, closeTo(2.0, epsilon));
      expect(result.y, closeTo(3.0, epsilon));
    });

    test('== operator', () {
      var t1 = const Translation2d(3.0, 4.0);
      var t2 = const Translation2d(3.0, 4.0);
      var t3 = const Translation2d(4.0, 3.0);
      expect(t1 == t2, isTrue);
      expect(t1 == t3, isFalse);
    });

    test('hashCode', () {
      var t1 = const Translation2d(3.0, 4.0);
      var t2 = const Translation2d(3.0, 4.0);
      var t3 = const Translation2d(4.0, 3.0);
      expect(t1.hashCode, equals(t2.hashCode));
      expect(t1.hashCode, isNot(equals(t3.hashCode)));
    });

    test('toString', () {
      var t = const Translation2d(3.0, 4.0);
      expect(t.toString(), equals('Translation2d(X: 3.00, Y: 4.00)'));
    });
  });

  group('Rotation2d', () {
    test('fromRadians', () {
      Rotation2d rot1 = Rotation2d.fromRadians(pi);
      Rotation2d rot2 = Rotation2d.fromRadians(pi / 2);
      Rotation2d rot3 = Rotation2d.fromRadians(-pi / 4);

      expect(rot1.radians, closeTo(pi, epsilon));
      expect(rot2.radians, closeTo(pi / 2, epsilon));
      expect(rot3.radians, closeTo(-pi / 4, epsilon));

      expect(rot1.degrees, closeTo(180, epsilon));
      expect(rot2.degrees, closeTo(90, epsilon));
      expect(rot3.degrees, closeTo(-45, epsilon));

      expect(rot1.rotations, closeTo(0.5, epsilon));
      expect(rot2.rotations, closeTo(0.25, epsilon));
      expect(rot3.rotations, closeTo(-0.125, epsilon));
    });

    test('fromDegrees', () {
      Rotation2d rot1 = Rotation2d.fromDegrees(180);
      Rotation2d rot2 = Rotation2d.fromDegrees(90);
      Rotation2d rot3 = Rotation2d.fromDegrees(-45);

      expect(rot1.radians, closeTo(pi, epsilon));
      expect(rot2.radians, closeTo(pi / 2, epsilon));
      expect(rot3.radians, closeTo(-pi / 4, epsilon));

      expect(rot1.degrees, closeTo(180, epsilon));
      expect(rot2.degrees, closeTo(90, epsilon));
      expect(rot3.degrees, closeTo(-45, epsilon));

      expect(rot1.rotations, closeTo(0.5, epsilon));
      expect(rot2.rotations, closeTo(0.25, epsilon));
      expect(rot3.rotations, closeTo(-0.125, epsilon));
    });

    test('fromRotations', () {
      Rotation2d rot1 = Rotation2d.fromRotations(0.5);
      Rotation2d rot2 = Rotation2d.fromRotations(0.25);
      Rotation2d rot3 = Rotation2d.fromRotations(-0.125);

      expect(rot1.radians, closeTo(pi, epsilon));
      expect(rot2.radians, closeTo(pi / 2, epsilon));
      expect(rot3.radians, closeTo(-pi / 4, epsilon));

      expect(rot1.degrees, closeTo(180, epsilon));
      expect(rot2.degrees, closeTo(90, epsilon));
      expect(rot3.degrees, closeTo(-45, epsilon));

      expect(rot1.rotations, closeTo(0.5, epsilon));
      expect(rot2.rotations, closeTo(0.25, epsilon));
      expect(rot3.rotations, closeTo(-0.125, epsilon));
    });
  });

  test('cosine', () {
    Rotation2d rot1 = Rotation2d.fromRadians(pi);
    Rotation2d rot2 = Rotation2d.fromRadians(pi / 2);
    Rotation2d rot3 = Rotation2d.fromRadians(-pi / 4);

    expect(rot1.cosine, closeTo(-1.0, epsilon));
    expect(rot2.cosine, closeTo(0.0, epsilon));
    expect(rot3.cosine, closeTo(0.707, epsilon));
  });

  test('sine', () {
    Rotation2d rot1 = Rotation2d.fromRadians(pi);
    Rotation2d rot2 = Rotation2d.fromRadians(pi / 2);
    Rotation2d rot3 = Rotation2d.fromRadians(-pi / 4);

    expect(rot1.sine, closeTo(0.0, epsilon));
    expect(rot2.sine, closeTo(1.0, epsilon));
    expect(rot3.sine, closeTo(-0.707, epsilon));
  });

  test('tangent', () {
    Rotation2d rot1 = Rotation2d.fromRadians(pi);
    Rotation2d rot2 = Rotation2d.fromRadians(pi / 3);
    Rotation2d rot3 = Rotation2d.fromRadians(-pi / 4);

    expect(rot1.tangent, closeTo(0.0, epsilon));
    expect(rot2.tangent, closeTo(1.732, epsilon));
    expect(rot3.tangent, closeTo(-1.0, epsilon));
  });

  test('plus', () {
    Rotation2d a = Rotation2d.fromDegrees(90);
    Rotation2d b = Rotation2d.fromDegrees(30);
    Rotation2d c = Rotation2d.fromDegrees(360);

    Rotation2d ab = a + b;
    Rotation2d ba = b + a;
    Rotation2d ac = a + c;

    expect(ab.degrees, closeTo(120.0, epsilon));
    expect(ba.degrees, closeTo(120.0, epsilon));
    expect(ac.degrees, closeTo(90.0, epsilon));
  });

  test('minus', () {
    Rotation2d a = Rotation2d.fromDegrees(90);
    Rotation2d b = Rotation2d.fromDegrees(30);
    Rotation2d c = Rotation2d.fromDegrees(360);

    Rotation2d ab = a - b;
    Rotation2d ba = b - a;
    Rotation2d ac = a - c;

    expect(ab.degrees, closeTo(60.0, epsilon));
    expect(ba.degrees, closeTo(-60.0, epsilon));
    expect(ac.degrees, closeTo(90.0, epsilon));
  });

  test('times', () {
    Rotation2d a = Rotation2d.fromDegrees(90) * 0.5;
    Rotation2d b = Rotation2d.fromDegrees(30) * 1.0;
    Rotation2d c = Rotation2d.fromDegrees(360) * 2.0;

    expect(a.degrees, closeTo(45.0, epsilon));
    expect(b.degrees, closeTo(30.0, epsilon));
    expect(c.degrees, closeTo(720.0, epsilon));
  });

  test('div', () {
    Rotation2d a = Rotation2d.fromDegrees(90) / 0.5;
    Rotation2d b = Rotation2d.fromDegrees(30) / 1.0;
    Rotation2d c = Rotation2d.fromDegrees(360) / 2.0;

    expect(a.degrees, closeTo(180.0, epsilon));
    expect(b.degrees, closeTo(30.0, epsilon));
    expect(c.degrees, closeTo(180.0, epsilon));
  });

  test('interpolate', () {
    Rotation2d a =
        Rotation2d.fromDegrees(0).interpolate(Rotation2d.fromDegrees(90), 0.5);
    Rotation2d b = Rotation2d.fromDegrees(-30)
        .interpolate(Rotation2d.fromDegrees(-90), 0.5);
    Rotation2d c = Rotation2d.fromDegrees(120)
        .interpolate(Rotation2d.fromDegrees(-120), 0.2);

    expect(a.degrees, closeTo(45.0, epsilon));
    expect(b.degrees, closeTo(-60.0, epsilon));
    expect(c.degrees, closeTo(144.0, epsilon));
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
