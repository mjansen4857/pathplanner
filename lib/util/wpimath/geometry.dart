import 'dart:math';
import 'dart:typed_data';

import 'package:pathplanner/util/wpimath/math_util.dart';
import 'package:pathplanner/util/wpimath/units.dart';

class Pose2d {
  final Translation2d translation;
  final Rotation2d rotation;

  const Pose2d(this.translation, this.rotation);

  num get x => translation.x;
  num get y => translation.y;

  factory Pose2d.fromBytes(Uint8List bytes) {
    final view = ByteData.view(bytes.buffer);

    int length = view.lengthInBytes;

    double xMeters = 0.0;
    double yMeters = 0.0;
    double angleRadians = 0.0;

    if (length >= 8) {
      xMeters = view.getFloat64(0, Endian.little);
    }
    if (length >= 16) {
      yMeters = view.getFloat64(8, Endian.little);
    }
    if (length >= 24) {
      angleRadians = view.getFloat64(16, Endian.little);
    }

    return Pose2d(
        Translation2d(xMeters, yMeters), Rotation2d.fromRadians(angleRadians));
  }

  Pose2d interpolate(Pose2d endValue, num t) {
    if (t < 0) {
      return this;
    } else if (t > 1) {
      return endValue;
    } else {
      return Pose2d(translation.interpolate(endValue.translation, t),
          rotation.interpolate(endValue.rotation, t));
    }
  }

  @override
  String toString() {
    return 'Pose2d($translation, $rotation)';
  }
}

class Translation2d {
  final num x;
  final num y;

  const Translation2d([
    this.x = 0.0,
    this.y = 0.0,
  ]);

  Translation2d.fromAngle(num distance, Rotation2d angle)
      : x = distance * angle.cosine,
        y = distance * angle.sine;

  Translation2d.fromJson(Map<String, dynamic> json)
      : this(json['x'] ?? 0, json['y'] ?? 0);

  num getDistance(Translation2d other) {
    return sqrt(pow(other.x - x, 2) + pow(other.y - y, 2));
  }

  num get norm => sqrt(pow(x, 2) + pow(y, 2));

  Rotation2d get angle => Rotation2d.fromComponents(x, y);

  Translation2d rotateBy(Rotation2d other) {
    return Translation2d(
      x * other.cosine - y * other.sine,
      x * other.sine + y * other.cosine,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }

  Translation2d operator +(Translation2d other) {
    return Translation2d(x + other.x, y + other.y);
  }

  Translation2d operator -(Translation2d other) {
    return Translation2d(x - other.x, y - other.y);
  }

  Translation2d operator -() {
    return Translation2d(-x, -y);
  }

  Translation2d operator *(num scalar) {
    return Translation2d(x * scalar, y * scalar);
  }

  Translation2d operator /(num scalar) {
    return Translation2d(x / scalar, y / scalar);
  }

  Translation2d interpolate(Translation2d endValue, num t) {
    return Translation2d(
      MathUtil.interpolate(x, endValue.x, t),
      MathUtil.interpolate(y, endValue.y, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Translation2d &&
      other.runtimeType == runtimeType &&
      (other.x - x).abs() < 0.001 &&
      (other.y - y).abs() < 0.001;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() {
    return 'Translation2d(X: ${x.toStringAsFixed(2)}, Y: ${y.toStringAsFixed(2)})';
  }
}

class Rotation2d {
  final num _value;
  final num _cos;
  final num _sin;

  Rotation2d([num radians = 0])
      : _value = radians,
        _cos = cos(radians),
        _sin = sin(radians);

  Rotation2d.fromSinCos(num sin, num cos) : this(atan2(sin, cos));

  factory Rotation2d.fromComponents(num x, num y) {
    num magnitude = sqrt(pow(x, 2) + pow(y, 2));
    if (magnitude > 1e-6) {
      return Rotation2d.fromSinCos(y / magnitude, x / magnitude);
    } else {
      return Rotation2d.fromSinCos(0.0, 1.0);
    }
  }

  Rotation2d.fromRadians(num radians) : this(radians);

  Rotation2d.fromDegrees(num degrees) : this(Units.degreesToRadians(degrees));

  Rotation2d.fromRotations(num rotations) : this(rotations * 2 * pi);

  Rotation2d rotateBy(Rotation2d other) {
    return Rotation2d.fromComponents(_cos * other._cos - _sin * other._sin,
        _cos * other._sin + _sin * other._cos);
  }

  Rotation2d operator +(Rotation2d other) {
    return rotateBy(other);
  }

  Rotation2d operator -() {
    return Rotation2d(-_value);
  }

  Rotation2d operator -(Rotation2d other) {
    return rotateBy(-other);
  }

  Rotation2d operator *(num scalar) {
    return Rotation2d(_value * scalar);
  }

  Rotation2d operator /(num scalar) {
    return Rotation2d(_value / scalar);
  }

  num get radians => _value;

  num get degrees => Units.radiansToDegrees(_value);

  num get rotations => _value / (pi * 2);

  num get cosine => _cos;

  num get sine => _sin;

  num get tangent => _sin / _cos;

  Rotation2d interpolate(Rotation2d endValue, num t) {
    return this + ((endValue - this) * MathUtil.clamp(t, 0, 1));
  }

  @override
  bool operator ==(Object other) =>
      other is Rotation2d &&
      other.runtimeType == runtimeType &&
      sqrt(pow(_cos - other._cos, 2) + pow(_sin - other._sin, 2)) < 1e-9;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() {
    return 'Rotation2d(Rads: ${radians.toStringAsFixed(2)}, Deg: ${degrees.toStringAsFixed(2)})';
  }
}
