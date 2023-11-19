import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/goal_end_state.dart';

void main() {
  test('Constructor functions', () {
    GoalEndState g = GoalEndState(
      velocity: 1.0,
      rotation: 2.0,
      rotateFast: true,
    );

    expect(g.velocity, 1.0);
    expect(g.rotation, 2.0);
    expect(g.rotateFast, true);
  });

  test('toJson/fromJson interoperability', () {
    GoalEndState g = GoalEndState(
      velocity: 1.0,
      rotation: 2.0,
      rotateFast: true,
    );

    Map<String, dynamic> json = g.toJson();
    GoalEndState fromJson = GoalEndState.fromJson(json);

    expect(fromJson, g);
  });

  test('Proper cloning', () {
    GoalEndState g = GoalEndState();
    GoalEndState cloned = g.clone();

    cloned.velocity = 2.5;

    expect(g, isNot(cloned));
  });

  test('equals/hashCode', () {
    GoalEndState g1 = GoalEndState(velocity: 1.0, rotation: 2.0);
    GoalEndState g2 = GoalEndState(velocity: 1.0, rotation: 2.0);
    GoalEndState g3 = GoalEndState(velocity: 1.5, rotation: 2.2);

    expect(g2, g1);
    expect(g3, isNot(g1));

    expect(g2.hashCode, g1.hashCode);
    expect(g3.hashCode, isNot(g1.hashCode));
  });
}
