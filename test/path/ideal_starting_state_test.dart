import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';

void main() {
  test('toJson/fromJson interoperability', () {
    IdealStartingState state = IdealStartingState(
      rotation: 10.0,
      velocity: 0.5,
    );

    Map<String, dynamic> json = state.toJson();
    IdealStartingState fromJson = IdealStartingState.fromJson(json);

    expect(fromJson, state);
  });

  test('Proper cloning', () {
    IdealStartingState state = IdealStartingState();
    IdealStartingState cloned = state.clone();

    expect(cloned, state);

    cloned.velocity = 2.5;

    expect(state, isNot(cloned));
  });

  test('equals/hashCode', () {
    IdealStartingState s1 = IdealStartingState(
      velocity: 1.0,
      rotation: 10.0,
    );
    IdealStartingState s2 = IdealStartingState(
      velocity: 1.0,
      rotation: 10.0,
    );
    IdealStartingState s3 = IdealStartingState(
      velocity: 1.5,
      rotation: 15.0,
    );

    expect(s2, s1);
    expect(s3, isNot(s1));

    expect(s2.hashCode, s1.hashCode);
    expect(s3.hashCode, isNot(s1.hashCode));
  });
}
