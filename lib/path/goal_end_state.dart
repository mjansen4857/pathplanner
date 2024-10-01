import 'package:pathplanner/util/wpimath/geometry.dart';

class GoalEndState {
  num velocityMPS;
  Rotation2d rotation;

  GoalEndState(this.velocityMPS, this.rotation);

  GoalEndState.fromJson(Map<String, dynamic> json)
      : velocityMPS = json['velocity'] ?? 0,
        rotation = Rotation2d.fromDegrees(json['rotation'] ?? 0);

  Map<String, dynamic> toJson() {
    return {
      'velocity': velocityMPS,
      'rotation': rotation.degrees,
    };
  }

  GoalEndState clone() {
    return GoalEndState(velocityMPS, rotation);
  }

  @override
  bool operator ==(Object other) =>
      other is GoalEndState &&
      other.runtimeType == runtimeType &&
      other.velocityMPS == velocityMPS &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(velocityMPS, rotation);
}
