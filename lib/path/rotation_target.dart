class RotationTarget {
  num waypointRelativePos;
  num rotationDegrees;
  bool rotateFast;

  RotationTarget({
    this.waypointRelativePos = 0.5,
    this.rotationDegrees = 0,
    this.rotateFast = false,
  });

  RotationTarget.fromJson(Map<String, dynamic> json)
      : waypointRelativePos = json['waypointRelativePos'] ?? 0.5,
        rotationDegrees = json['rotationDegrees'] ?? 0,
        rotateFast = json['rotateFast'] ?? false;

  Map<String, dynamic> toJson() {
    return {
      'waypointRelativePos': waypointRelativePos,
      'rotationDegrees': rotationDegrees,
      'rotateFast': rotateFast,
    };
  }

  RotationTarget clone() {
    return RotationTarget(
      waypointRelativePos: waypointRelativePos,
      rotationDegrees: rotationDegrees,
      rotateFast: rotateFast,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RotationTarget &&
      other.runtimeType == runtimeType &&
      other.waypointRelativePos == waypointRelativePos &&
      other.rotationDegrees == rotationDegrees &&
      other.rotateFast == rotateFast;

  @override
  int get hashCode =>
      Object.hash(waypointRelativePos, rotationDegrees, rotateFast);
}
