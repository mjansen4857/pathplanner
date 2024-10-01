import 'package:pathplanner/util/wpimath/geometry.dart';

class RotationTarget {
  num waypointRelativePos;
  Rotation2d rotation;

  RotationTarget(this.waypointRelativePos, this.rotation);

  RotationTarget.fromJson(Map<String, dynamic> json)
      : waypointRelativePos = json['waypointRelativePos'] ?? 0.5,
        rotation = Rotation2d.fromDegrees(json['rotationDegrees'] ?? 0);

  Map<String, dynamic> toJson() {
    return {
      'waypointRelativePos': waypointRelativePos,
      'rotationDegrees': rotation.degrees,
    };
  }

  RotationTarget clone() {
    return RotationTarget(waypointRelativePos, rotation);
  }

  @override
  bool operator ==(Object other) =>
      other is RotationTarget &&
      other.runtimeType == runtimeType &&
      other.waypointRelativePos == waypointRelativePos &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(waypointRelativePos, rotation);
}
