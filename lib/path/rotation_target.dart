import 'package:pathplanner/util/wpimath/geometry.dart';

class RotationTarget {
  num waypointRelativePos;
  Rotation2d rotation;
  final bool displayInEditor;

  RotationTarget(this.waypointRelativePos, this.rotation, [this.displayInEditor = true]);

  RotationTarget.fromJson(Map<String, dynamic> json)
      : this(json['waypointRelativePos'] ?? 0.5,
            Rotation2d.fromDegrees(json['rotationDegrees'] ?? 0));

  Map<String, dynamic> toJson() {
    return {
      'waypointRelativePos': waypointRelativePos,
      'rotationDegrees': rotation.degrees,
    };
  }

  RotationTarget clone() {
    return RotationTarget(waypointRelativePos, rotation, displayInEditor);
  }

  RotationTarget reverse() {
    return RotationTarget(
        waypointRelativePos, rotation.rotateBy(Rotation2d.fromDegrees(180)), displayInEditor);
  }

  RotationTarget reverseH() {
    return RotationTarget(waypointRelativePos, -rotation, displayInEditor);
  }

  @override
  bool operator ==(Object other) =>
      other is RotationTarget &&
      other.runtimeType == runtimeType &&
      other.waypointRelativePos == waypointRelativePos &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(waypointRelativePos, rotation);

  @override
  String toString() {
    return 'RotationTarget($waypointRelativePos, $rotation)';
  }
}
