import 'dart:math';

class StartingPose {
  Point position;
  num rotation;

  StartingPose({
    required this.position,
    required this.rotation,
  });

  StartingPose.defaultPose() : this(position: const Point(2, 2), rotation: 0);

  StartingPose.fromJson(Map<String, dynamic> json)
      : this(
          position: _pointFromJson(json['position']),
          rotation: json['rotation'] ?? 0,
        );

  static Point _pointFromJson(Map<String, dynamic>? pointJson) {
    if (pointJson == null) {
      return const Point(2, 2);
    }

    return Point(pointJson['x'] ?? 2, pointJson['y'] ?? 2);
  }

  Map<String, dynamic> toJson() {
    return {
      'position': {
        'x': position.x,
        'y': position.y,
      },
      'rotation': rotation,
    };
  }

  StartingPose clone() {
    return StartingPose(
      position: Point(position.x, position.y),
      rotation: rotation,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StartingPose &&
      other.runtimeType == runtimeType &&
      other.position == position &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(position, rotation);
}
