import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/starting_pose.dart';

void main() {
  test('equals/hashCode', () {
    StartingPose pose1 = StartingPose(
      position: const Point(1.1, 2.0),
      rotation: 5.0,
    );
    StartingPose pose2 = StartingPose(
      position: const Point(1.1, 2.0),
      rotation: 5.0,
    );
    StartingPose pose3 = StartingPose(
      position: const Point(1.5, 2.0),
      rotation: 90.0,
    );

    expect(pose2, pose1);
    expect(pose3, isNot(pose1));

    expect(pose2.hashCode, pose1.hashCode);
    expect(pose3.hashCode, isNot(pose1.hashCode));
  });

  test('toJson/fromJson interoperability', () {
    StartingPose pose = StartingPose(
      position: const Point(1.1, 2.0),
      rotation: 5.0,
    );

    Map<String, dynamic> json = pose.toJson();
    StartingPose fromJson = StartingPose.fromJson(json);

    expect(fromJson, pose);
  });

  test('proper cloning', () {
    StartingPose pose = StartingPose.defaultPose();
    StartingPose cloned = pose.clone();

    expect(cloned, pose);

    cloned.position = const Point(0.0, 1.0);

    expect(cloned, isNot(pose));

    cloned.rotation = -20;

    expect(cloned, isNot(pose));
  });
}
