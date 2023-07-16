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
      this.name = 'New Constraints Zone'});

  ConstraintsZone.defaultZone() : this(constraints: PathConstraints());

  ConstraintsZone clone() {
    return ConstraintsZone(
      minWaypointRelativePos: minWaypointRelativePos,
      maxWaypointRelativePos: maxWaypointRelativePos,
      constraints: constraints.clone(),
      name: name,
    );
  }
}
