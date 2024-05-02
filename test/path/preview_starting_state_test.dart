import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/preview_starting_state.dart';

void main() {
  test('toJson/fromJson interoperability', () {
    PreviewStartingState state = PreviewStartingState(
      rotation: 10.0,
      velocity: 0.5,
    );

    Map<String, dynamic> json = state.toJson();
    PreviewStartingState fromJson = PreviewStartingState.fromJson(json);

    expect(fromJson, state);
  });

  test('Proper cloning', () {
    PreviewStartingState state = PreviewStartingState();
    PreviewStartingState cloned = state.clone();

    expect(cloned, state);

    cloned.velocity = 2.5;

    expect(state, isNot(cloned));
  });

  test('equals/hashCode', () {
    PreviewStartingState s1 = PreviewStartingState(
      velocity: 1.0,
      rotation: 10.0,
    );
    PreviewStartingState s2 = PreviewStartingState(
      velocity: 1.0,
      rotation: 10.0,
    );
    PreviewStartingState s3 = PreviewStartingState(
      velocity: 1.5,
      rotation: 15.0,
    );

    expect(s2, s1);
    expect(s3, isNot(s1));

    expect(s2.hashCode, s1.hashCode);
    expect(s3.hashCode, isNot(s1.hashCode));
  });
}
