import 'package:pathplanner/util/wpimath/geometry.dart';

class IdealStartingState {
  num velocityMPS;
  Rotation2d rotation;

  IdealStartingState(this.velocityMPS, this.rotation);

  IdealStartingState.fromJson(Map<String, dynamic> json)
      : velocityMPS = json['velocity'] ?? 0,
        rotation = Rotation2d.fromDegrees(json['rotation'] ?? 0);

  Map<String, dynamic> toJson() {
    return {
      'velocity': velocityMPS,
      'rotation': rotation.degrees,
    };
  }

  IdealStartingState clone() {
    return IdealStartingState(velocityMPS, rotation);
  }

  IdealStartingState reverse() {
    return IdealStartingState(velocityMPS, rotation.rotateBy(Rotation2d.fromDegrees(180)));
  }

  IdealStartingState reverseH() {
    return IdealStartingState(velocityMPS, -rotation);
  }

  @override
  bool operator ==(Object other) =>
      other is IdealStartingState &&
      other.runtimeType == runtimeType &&
      other.velocityMPS == velocityMPS &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(velocityMPS, rotation);
}
