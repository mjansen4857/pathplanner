import 'package:pathplanner/util/wpimath/geometry.dart';

class PointTowardsZone {
  Translation2d fieldPosition;
  Rotation2d rotationOffset;

  num minWaypointRelativePos;
  num maxWaypointRelativePos;

  String name;

  PointTowardsZone({
    this.fieldPosition = const Translation2d(0.4, 5.5),
    this.rotationOffset = const Rotation2d(),
    this.minWaypointRelativePos = 0.25,
    this.maxWaypointRelativePos = 0.75,
    this.name = 'Point Towards Zone',
  });

  PointTowardsZone.fromJson(Map<String, dynamic> json)
      : this(
          fieldPosition: Translation2d.fromJson(json['fieldPosition']),
          rotationOffset: Rotation2d.fromDegrees(json['rotationOffset']),
          minWaypointRelativePos: json['minWaypointRelativePos'],
          maxWaypointRelativePos: json['maxWaypointRelativePos'],
          name: json['name'],
        );

  PointTowardsZone clone() {
    return PointTowardsZone(
      fieldPosition: fieldPosition,
      rotationOffset: rotationOffset,
      minWaypointRelativePos: minWaypointRelativePos,
      maxWaypointRelativePos: maxWaypointRelativePos,
      name: name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fieldPosition': fieldPosition.toJson(),
      'rotationOffset': rotationOffset.degrees,
      'minWaypointRelativePos': minWaypointRelativePos,
      'maxWaypointRelativePos': maxWaypointRelativePos,
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is PointTowardsZone &&
        other.runtimeType == runtimeType &&
        other.fieldPosition == fieldPosition &&
        other.rotationOffset == rotationOffset &&
        other.minWaypointRelativePos == minWaypointRelativePos &&
        other.maxWaypointRelativePos == maxWaypointRelativePos &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(fieldPosition, rotationOffset,
      minWaypointRelativePos, maxWaypointRelativePos, name);
}
