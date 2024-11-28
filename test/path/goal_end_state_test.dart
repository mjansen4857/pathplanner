import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  test('Constructor functions', () {
    GoalEndState g = GoalEndState(1.0, const Rotation2d(2.0));

    expect(g.velocityMPS, 1.0);
    expect(g.rotation.radians, 2.0);
  });

  test('toJson/fromJson interoperability', () {
    GoalEndState g = GoalEndState(1.0, const Rotation2d(2.0));

    Map<String, dynamic> json = g.toJson();
    GoalEndState fromJson = GoalEndState.fromJson(json);

    expect(fromJson, g);
  });

  test('Proper cloning', () {
    GoalEndState g = GoalEndState(1.0, const Rotation2d(2.0));
    GoalEndState cloned = g.clone();

    cloned.velocityMPS = 2.5;

    expect(g, isNot(cloned));
  });

  test('equals/hashCode', () {
    GoalEndState g1 = GoalEndState(1.0, const Rotation2d(2.0));
    GoalEndState g2 = GoalEndState(1.0, const Rotation2d(2.0));
    GoalEndState g3 = GoalEndState(1.5, const Rotation2d(2.2));

    expect(g2, g1);
    expect(g3, isNot(g1));

    expect(g2.hashCode, g1.hashCode);
    expect(g3.hashCode, isNot(g1.hashCode));
  });
}
