import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

const num epsilon = 0.001;

void main() {
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
