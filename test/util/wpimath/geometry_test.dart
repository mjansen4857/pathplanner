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
}
