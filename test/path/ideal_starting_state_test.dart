import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  test('toJson/fromJson interoperability', () {
    IdealStartingState state = IdealStartingState(0.5, const Rotation2d(2.0));

    Map<String, dynamic> json = state.toJson();
    IdealStartingState fromJson = IdealStartingState.fromJson(json);

    expect(fromJson, state);
  });

  test('Proper cloning', () {
    IdealStartingState state = IdealStartingState(0.5, const Rotation2d(2.0));
    IdealStartingState cloned = state.clone();

    expect(cloned, state);

    cloned.velocityMPS = 2.5;

    expect(state, isNot(cloned));
  });

  test('equals/hashCode', () {
    IdealStartingState s1 = IdealStartingState(0.5, const Rotation2d(2.0));
    IdealStartingState s2 = IdealStartingState(0.5, const Rotation2d(2.0));
    IdealStartingState s3 = IdealStartingState(1.5, const Rotation2d(2.5));

    expect(s2, s1);
    expect(s3, isNot(s1));

    expect(s2.hashCode, s1.hashCode);
    expect(s3.hashCode, isNot(s1.hashCode));
  });
}
