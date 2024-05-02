import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/util/pose2d.dart';

void main() {
  test('equals/hashCode', () {
    Pose2d pose1 = Pose2d(
      position: const Point(1.1, 2.0),
      rotation: 5.0,
    );
    Pose2d pose2 = Pose2d(
      position: const Point(1.1, 2.0),
      rotation: 5.0,
    );
    Pose2d pose3 = Pose2d(
      position: const Point(1.5, 2.0),
      rotation: 90.0,
    );

    expect(pose2, pose1);
    expect(pose3, isNot(pose1));

    expect(pose2.hashCode, pose1.hashCode);
    expect(pose3.hashCode, isNot(pose1.hashCode));
  });

  test('toJson/fromJson interoperability', () {
    Pose2d pose = Pose2d(
      position: const Point(1.1, 2.0),
      rotation: 5.0,
    );

    Map<String, dynamic> json = pose.toJson();
    Pose2d fromJson = Pose2d.fromJson(json);

    expect(fromJson, pose);
  });

  test('proper cloning', () {
    Pose2d pose = Pose2d();
    Pose2d cloned = pose.clone();

    expect(cloned, pose);

    cloned.position = const Point(0.0, 1.0);

    expect(cloned, isNot(pose));

    cloned.rotation = -20;

    expect(cloned, isNot(pose));
  });
}
