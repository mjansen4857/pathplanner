import 'package:pathplanner/path/path_constraints.dart';

class ConstraintsZone {
  num minWaypointRelativePos;
  num maxWaypointRelativePos;
  PathConstraints constraints;

  ConstraintsZone({
    this.minWaypointRelativePos = 0,
    this.maxWaypointRelativePos = 0,
    required this.constraints,
  });

  ConstraintsZone.defaultZone() : this(constraints: PathConstraints());

  ConstraintsZone clone() {
    return ConstraintsZone(
      minWaypointRelativePos: minWaypointRelativePos,
      maxWaypointRelativePos: maxWaypointRelativePos,
      constraints: constraints.clone(),
    );
  }
}
