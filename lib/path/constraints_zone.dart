import 'package:pathplanner/path/path_constraints.dart';

class ConstraintsZone {
  num minWaypointRelativePos;
  num maxWaypointRelativePos;
  PathConstraints constraints;

  String name;

  ConstraintsZone(
      {this.minWaypointRelativePos = 0,
      this.maxWaypointRelativePos = 0,
      required this.constraints,
      this.name = 'Constraints Zone'});

  ConstraintsZone.defaultZone({PathConstraints? constraints})
      : this(constraints: constraints ?? PathConstraints());

  ConstraintsZone.fromJson(Map<String, dynamic> json)
      : name = json['name'] ?? 'Constraints Zone',
        minWaypointRelativePos = json['minWaypointRelativePos'],
        maxWaypointRelativePos = json['maxWaypointRelativePos'],
        constraints = PathConstraints.fromJson(json['constraints'] ?? {});

  ConstraintsZone clone() {
    return ConstraintsZone(
      minWaypointRelativePos: minWaypointRelativePos,
      maxWaypointRelativePos: maxWaypointRelativePos,
      constraints: constraints.clone(),
      name: name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'minWaypointRelativePos': minWaypointRelativePos,
      'maxWaypointRelativePos': maxWaypointRelativePos,
      'constraints': constraints.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ConstraintsZone &&
      other.runtimeType == runtimeType &&
      other.name == name &&
      other.minWaypointRelativePos == minWaypointRelativePos &&
      other.maxWaypointRelativePos == maxWaypointRelativePos &&
      other.constraints == constraints;

  @override
  int get hashCode => Object.hash(
      name, minWaypointRelativePos, maxWaypointRelativePos, constraints);
}
