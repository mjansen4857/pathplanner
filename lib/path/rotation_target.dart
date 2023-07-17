class RotationTarget {
  num waypointRelativePos;
  num rotationDegrees;

  RotationTarget({
    this.waypointRelativePos = 0.5,
    this.rotationDegrees = 0,
  });

  RotationTarget.fromJson(Map<String, dynamic> json)
      : waypointRelativePos = json['waypointRelativePos'] ?? 0.5,
        rotationDegrees = json['rotationDegrees'] ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'waypointRelativePos': waypointRelativePos,
      'rotationDegrees': rotationDegrees,
    };
  }

  RotationTarget clone() {
    return RotationTarget(
      waypointRelativePos: waypointRelativePos,
      rotationDegrees: rotationDegrees,
    );
  }
}
