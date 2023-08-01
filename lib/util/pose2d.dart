import 'dart:math';

class Pose2d {
  Point position;
  num rotation;

  Pose2d({
    this.position = const Point(0, 0),
    this.rotation = 0,
  });

  Pose2d.fromJson(Map<String, dynamic> json)
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

  Pose2d clone() {
    return Pose2d(
      position: Point(position.x, position.y),
      rotation: rotation,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Pose2d &&
      other.runtimeType == runtimeType &&
      other.position == position &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(position, rotation);
}
