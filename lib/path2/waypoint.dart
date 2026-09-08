import 'dart:math';

import 'package:collection/collection.dart';

import 'package:pathplanner/util/wpimath/geometry.dart';

enum WaypointType { pose, translation, pointTowards }

abstract class Waypoint {
  static const num defaultMaxVelocity = 4.0;
  static const num defaultMaxAngularVelocity = 360.0;
  static const num defaultMaxAngularAcceleration = 720.0;

  List<String> events;
  Translation2d position;
  num maxVelocity;
  num maxAngularVelocity;
  num maxAngularAcceleration;

  bool _isDragging = false;

  Waypoint({
    required this.position,
    List<String> events = const [],
    this.maxVelocity = defaultMaxVelocity,
    this.maxAngularVelocity = defaultMaxAngularVelocity,
    this.maxAngularAcceleration = defaultMaxAngularAcceleration,
  }) : events = List.of(events) {
    if (events.any((name) => name.trim().isEmpty)) {
      throw ArgumentError('Event names must be nonempty');
    }
    _validateFinite(position.x, 'position.x');
    _validateFinite(position.y, 'position.y');
    _validateNonNegativeFinite(maxVelocity, 'maxVelocity');
    _validateNonNegativeFinite(maxAngularVelocity, 'maxAngularVelocity');
    _validateNonNegativeFinite(
      maxAngularAcceleration,
      'maxAngularAcceleration',
    );
  }

  bool get isDragging => _isDragging;

  bool get isAnchorDragging => _isDragging;

  void move(num x, num y) {
    _validateFinite(x, 'x');
    _validateFinite(y, 'y');
    position = Translation2d(x, y);
  }

  bool isPointInAnchor(num xPos, num yPos, num radius) {
    return pow(xPos - position.x, 2) + pow(yPos - position.y, 2) <
        pow(radius, 2);
  }

  bool startDragging(num xPos, num yPos, num radius) {
    if (isPointInAnchor(xPos, yPos, radius)) {
      _isDragging = true;
    }
    return _isDragging;
  }

  void dragUpdate(num x, num y) {
    if (_isDragging) {
      move(x, y);
    }
  }

  void stopDragging() {
    _isDragging = false;
  }

  WaypointType get type;

  Waypoint clone();

  Waypoint convertedTo(WaypointType type) {
    return switch (type) {
      WaypointType.pose => PoseWaypoint(
        position: position,
        events: events,
        rotation: this is PoseWaypoint
            ? (this as PoseWaypoint).rotation
            : const Rotation2d(),
        maxVelocity: maxVelocity,
        maxAngularVelocity: maxAngularVelocity,
        maxAngularAcceleration: maxAngularAcceleration,
      ),
      WaypointType.translation => TranslationWaypoint(
        position: position,
        events: events,
        maxVelocity: maxVelocity,
        maxAngularVelocity: maxAngularVelocity,
        maxAngularAcceleration: maxAngularAcceleration,
      ),
      WaypointType.pointTowards => PointTowardsWaypoint(
        position: position,
        events: events,
        targetPosition: this is PointTowardsWaypoint
            ? (this as PointTowardsWaypoint).targetPosition
            : PointTowardsWaypoint.defaultTargetPosition,
        rotationOffset: this is PointTowardsWaypoint
            ? (this as PointTowardsWaypoint).rotationOffset
            : const Rotation2d(),
        unprofiled: this is PointTowardsWaypoint
            ? (this as PointTowardsWaypoint).unprofiled
            : false,
        inheritTargetFromParent: this is PointTowardsWaypoint
            ? (this as PointTowardsWaypoint).inheritTargetFromParent
            : false,
        maxVelocity: maxVelocity,
        maxAngularVelocity: maxAngularVelocity,
        maxAngularAcceleration: maxAngularAcceleration,
      ),
    };
  }

  Waypoint withRotation(Rotation2d? rotation) {
    if (rotation == null) {
      return TranslationWaypoint(
        position: position,
        events: events,
        maxVelocity: maxVelocity,
        maxAngularVelocity: maxAngularVelocity,
        maxAngularAcceleration: maxAngularAcceleration,
      );
    }

    return PoseWaypoint(
      position: position,
      events: events,
      rotation: rotation,
      maxVelocity: maxVelocity,
      maxAngularVelocity: maxAngularVelocity,
      maxAngularAcceleration: maxAngularAcceleration,
    );
  }

  Map<String, dynamic> toJson();

  static Waypoint fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String) {
      throw const FormatException('Waypoint type must be a string');
    }

    return switch (type) {
      'pose' => PoseWaypoint.fromJson(json),
      'translation' => TranslationWaypoint.fromJson(json),
      'pointTowards' => PointTowardsWaypoint.fromJson(json),
      _ => throw FormatException('Unknown waypoint type: $type'),
    };
  }

  Map<String, dynamic> commonJson(String type) {
    return {
      'type': type,
      'events': List<String>.of(events),
      'position': position.toJson(),
      'maxVelocity': maxVelocity,
      'maxAngularVelocity': maxAngularVelocity,
      'maxAngularAcceleration': maxAngularAcceleration,
    };
  }

  bool commonEquals(Waypoint other) {
    return const ListEquality<String>().equals(other.events, events) &&
        other.position == position &&
        other.maxVelocity == maxVelocity &&
        other.maxAngularVelocity == maxAngularVelocity &&
        other.maxAngularAcceleration == maxAngularAcceleration;
  }

  int get commonHashCode => Object.hash(
    const ListEquality<String>().hash(events),
    position,
    maxVelocity,
    maxAngularVelocity,
    maxAngularAcceleration,
  );
}

class TranslationWaypoint extends Waypoint {
  TranslationWaypoint({
    required super.position,
    super.events,
    super.maxVelocity,
    super.maxAngularVelocity,
    super.maxAngularAcceleration,
  });

  TranslationWaypoint.fromJson(Map<String, dynamic> json)
    : this(
        position: _positionFromJson(json),
        events: _eventsFromJson(json['events']),
        maxVelocity: _optionalNonNegativeNum(
          json,
          'maxVelocity',
          Waypoint.defaultMaxVelocity,
        ),
        maxAngularVelocity: _optionalNonNegativeNum(
          json,
          'maxAngularVelocity',
          Waypoint.defaultMaxAngularVelocity,
        ),
        maxAngularAcceleration: _optionalNonNegativeNum(
          json,
          'maxAngularAcceleration',
          Waypoint.defaultMaxAngularAcceleration,
        ),
      );

  @override
  WaypointType get type => WaypointType.translation;

  @override
  TranslationWaypoint clone() {
    return TranslationWaypoint(
      position: position,
      events: events,
      maxVelocity: maxVelocity,
      maxAngularVelocity: maxAngularVelocity,
      maxAngularAcceleration: maxAngularAcceleration,
    );
  }

  @override
  Map<String, dynamic> toJson() => commonJson('translation');

  @override
  bool operator ==(Object other) =>
      other is TranslationWaypoint && commonEquals(other);

  @override
  int get hashCode => commonHashCode;
}

class PoseWaypoint extends Waypoint {
  Rotation2d rotation;

  PoseWaypoint({
    required super.position,
    super.events,
    required this.rotation,
    super.maxVelocity,
    super.maxAngularVelocity,
    super.maxAngularAcceleration,
  }) {
    _validateFinite(rotation.radians, 'rotation');
  }

  PoseWaypoint.fromJson(Map<String, dynamic> json)
    : this(
        position: _positionFromJson(json),
        events: _eventsFromJson(json['events']),
        rotation: _rotationFromJson(json),
        maxVelocity: _optionalNonNegativeNum(
          json,
          'maxVelocity',
          Waypoint.defaultMaxVelocity,
        ),
        maxAngularVelocity: _optionalNonNegativeNum(
          json,
          'maxAngularVelocity',
          Waypoint.defaultMaxAngularVelocity,
        ),
        maxAngularAcceleration: _optionalNonNegativeNum(
          json,
          'maxAngularAcceleration',
          Waypoint.defaultMaxAngularAcceleration,
        ),
      );

  @override
  WaypointType get type => WaypointType.pose;

  @override
  PoseWaypoint clone() {
    return PoseWaypoint(
      position: position,
      events: events,
      rotation: rotation,
      maxVelocity: maxVelocity,
      maxAngularVelocity: maxAngularVelocity,
      maxAngularAcceleration: maxAngularAcceleration,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {...commonJson('pose'), 'rotation': rotation.toJson()};
  }

  @override
  bool operator ==(Object other) =>
      other is PoseWaypoint &&
      commonEquals(other) &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(commonHashCode, rotation);
}

class PointTowardsWaypoint extends Waypoint {
  static const Translation2d defaultTargetPosition = Translation2d(-7.6, 1.5);

  Translation2d targetPosition;
  Rotation2d rotationOffset;
  bool unprofiled;
  bool inheritTargetFromParent;

  PointTowardsWaypoint({
    required super.position,
    super.events,
    this.targetPosition = defaultTargetPosition,
    this.rotationOffset = const Rotation2d(),
    this.unprofiled = false,
    this.inheritTargetFromParent = false,
    super.maxVelocity,
    super.maxAngularVelocity,
    super.maxAngularAcceleration,
  }) {
    _validateFinite(targetPosition.x, 'targetPosition.x');
    _validateFinite(targetPosition.y, 'targetPosition.y');
    _validateFinite(rotationOffset.radians, 'rotationOffset');
  }

  PointTowardsWaypoint.fromJson(Map<String, dynamic> json)
    : this(
        position: _positionFromJson(json),
        events: _eventsFromJson(json['events']),
        targetPosition: _translationFromJson(
          json,
          'targetPosition',
          'Point-towards waypoint target position',
        ),
        rotationOffset: Rotation2d.fromDegrees(
          _optionalFiniteNum(json, 'rotationOffset', 0),
        ),
        unprofiled: _optionalBool(json, 'unprofiled', false),
        inheritTargetFromParent: _optionalBool(
          json,
          'inheritTargetFromParent',
          false,
        ),
        maxVelocity: _optionalNonNegativeNum(
          json,
          'maxVelocity',
          Waypoint.defaultMaxVelocity,
        ),
        maxAngularVelocity: _optionalNonNegativeNum(
          json,
          'maxAngularVelocity',
          Waypoint.defaultMaxAngularVelocity,
        ),
        maxAngularAcceleration: _optionalNonNegativeNum(
          json,
          'maxAngularAcceleration',
          Waypoint.defaultMaxAngularAcceleration,
        ),
      );

  @override
  WaypointType get type => WaypointType.pointTowards;

  void moveTarget(num x, num y) {
    _validateFinite(x, 'x');
    _validateFinite(y, 'y');
    targetPosition = Translation2d(x, y);
  }

  @override
  PointTowardsWaypoint clone() {
    return PointTowardsWaypoint(
      position: position,
      events: events,
      targetPosition: targetPosition,
      rotationOffset: rotationOffset,
      unprofiled: unprofiled,
      inheritTargetFromParent: inheritTargetFromParent,
      maxVelocity: maxVelocity,
      maxAngularVelocity: maxAngularVelocity,
      maxAngularAcceleration: maxAngularAcceleration,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...commonJson('pointTowards'),
      'targetPosition': targetPosition.toJson(),
      'rotationOffset': rotationOffset.degrees,
      'unprofiled': unprofiled,
      'inheritTargetFromParent': inheritTargetFromParent,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PointTowardsWaypoint &&
      commonEquals(other) &&
      other.targetPosition == targetPosition &&
      other.rotationOffset == rotationOffset &&
      other.unprofiled == unprofiled &&
      other.inheritTargetFromParent == inheritTargetFromParent;

  @override
  int get hashCode => Object.hash(
    commonHashCode,
    targetPosition,
    rotationOffset,
    unprofiled,
    inheritTargetFromParent,
  );
}

Translation2d _positionFromJson(Map<String, dynamic> json) {
  return _translationFromJson(json, 'position', 'Waypoint position');
}

Translation2d _translationFromJson(
  Map<String, dynamic> json,
  String key,
  String label,
) {
  final position = json[key];
  if (position is! Map<String, dynamic>) {
    throw FormatException('$label must be an object');
  }

  final x = position['x'];
  final y = position['y'];
  if (x is! num || y is! num || !x.isFinite || !y.isFinite) {
    throw FormatException('$label must contain finite x and y values');
  }

  return Translation2d(x, y);
}

Rotation2d _rotationFromJson(Map<String, dynamic> json) {
  final rotation = json['rotation'];
  if (rotation is! Map<String, dynamic>) {
    throw const FormatException('Pose waypoint rotation must be an object');
  }

  final value = rotation['value'];
  if (value is! num || !value.isFinite) {
    throw const FormatException(
      'Pose waypoint rotation must contain a finite value',
    );
  }

  return Rotation2d(value);
}

num _optionalNonNegativeNum(
  Map<String, dynamic> json,
  String key,
  num defaultValue,
) {
  final value = json[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('$key must be a finite non-negative number');
  }
  return value;
}

num _optionalFiniteNum(
  Map<String, dynamic> json,
  String key,
  num defaultValue,
) {
  final value = json[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is! num || !value.isFinite) {
    throw FormatException('$key must be a finite number');
  }
  return value;
}

bool _optionalBool(Map<String, dynamic> json, String key, bool defaultValue) {
  final value = json[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is! bool) {
    throw FormatException('$key must be a boolean');
  }
  return value;
}

void _validateFinite(num value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite');
  }
}

void _validateNonNegativeFinite(num value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and non-negative');
  }
}

List<String> _eventsFromJson(Object? value) {
  if (value == null) return [];
  if (value is! List ||
      value.any((name) => name is! String || name.trim().isEmpty)) {
    throw const FormatException('Events must be a list of nonempty strings');
  }
  return List<String>.from(value);
}
