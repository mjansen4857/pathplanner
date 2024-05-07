import 'dart:math';

import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';

class Pose2d {
  final Translation2d translation;
  final Rotation2d rotation;

  const Pose2d(this.translation, this.rotation);
}

class Translation2d {
  final num x;
  final num y;

  const Translation2d({
    this.x = 0.0,
    this.y = 0.0,
  });

  Translation2d.fromAngle(num distance, Rotation2d angle)
      : x = distance * angle.getCos(),
        y = distance * angle.getSin();

  num getDistance(Translation2d other) {
    return sqrt(pow(other.x - x, 2) + pow(other.y - y, 2));
  }

  num getNorm() {
    return sqrt(pow(x, 2) + pow(y, 2));
  }

  Rotation2d getAngle() {
    return Rotation2d.fromComponents(x, y);
  }

  Translation2d rotateBy(Rotation2d other) {
    return Translation2d(
      x: x * other.getCos() - y * other.getSin(),
      y: x * other.getSin() + y * other.getCos(),
    );
  }

  Translation2d operator +(Translation2d other) {
    return Translation2d(x: x + other.x, y: y + other.y);
  }

  Translation2d operator -(Translation2d other) {
    return Translation2d(x: x - other.x, y: y - other.y);
  }

  Translation2d operator -() {
    return Translation2d(x: -x, y: -y);
  }

  Translation2d operator *(num scalar) {
    return Translation2d(x: x * scalar, y: y * scalar);
  }

  Translation2d operator /(num scalar) {
    return Translation2d(x: x / scalar, y: y / scalar);
  }

  Translation2d interpolate(Translation2d endValue, num t) {
    return Translation2d(
      x: MathUtil.interpolate(x, endValue.x, t),
      y: MathUtil.interpolate(y, endValue.y, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Translation2d &&
      other.runtimeType == runtimeType &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() {
    return 'Translation2d(X: ${x.toStringAsFixed(2)}, Y: ${y.toStringAsFixed(2)})';
  }
}

class Rotation2d {
  late final num _value;
  late final num _cos;
  late final num _sin;

  Rotation2d({num radians = 0})
      : _value = radians,
        _cos = cos(radians),
        _sin = sin(radians);

  Rotation2d.fromComponents(num x, num y) {
    num magnitude = sqrt(pow(x, 2) + pow(y, 2));
    if (magnitude > 1e-6) {
      _sin = y / magnitude;
      _cos = x / magnitude;
    } else {
      _sin = 0.0;
      _cos = 1.0;
    }
    _value = atan2(_sin, _cos);
  }

  Rotation2d.fromRadians(num radians) : this(radians: radians);

  Rotation2d.fromDegrees(num degrees)
      : this(radians: GeometryUtil.toRadians(degrees));

  Rotation2d.fromRotations(num rotations) : this(radians: rotations * 2 * pi);

  Rotation2d rotateBy(Rotation2d other) {
    return Rotation2d.fromComponents(_cos * other._cos - _sin * other._sin,
        _cos * other._sin + _sin * other._cos);
  }

  Rotation2d operator +(Rotation2d other) {
    return rotateBy(other);
  }

  Rotation2d operator -() {
    return Rotation2d(radians: -_value);
  }

  Rotation2d operator -(Rotation2d other) {
    return rotateBy(-other);
  }

  Rotation2d operator *(num scalar) {
    return Rotation2d(radians: _value * scalar);
  }

  Rotation2d operator /(num scalar) {
    return Rotation2d(radians: _value / scalar);
  }

  num getRadians() {
    return _value;
  }

  num getDegrees() {
    return GeometryUtil.toDegrees(_value);
  }

  num getRotations() {
    return _value / (pi * 2);
  }

  num getCos() {
    return _cos;
  }

  num getSin() {
    return _sin;
  }

  num getTan() {
    return _sin / _cos;
  }

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
    return 'Rotation2d(Rads: ${_value.toStringAsFixed(2)}, Deg: ${getDegrees().toStringAsFixed(2)})';
  }
}
