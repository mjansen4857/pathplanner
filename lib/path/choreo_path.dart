import 'dart:math';

import 'package:pathplanner/services/simulator/trajectory_generator.dart';

class ChoreoPath {
  final String name;
  final Trajectory trajectory;

  const ChoreoPath({
    required this.name,
    required this.trajectory,
  });

  ChoreoPath.fromChorJsonV0_1_1(Map<String, dynamic> json, String name)
      : this(
          name: name,
          trajectory: Trajectory(
            states: [
              for (Map<String, dynamic> s in json['trajectory'])
                TrajectoryState(
                  time: s['timestamp'],
                  position: Point(s['x'], s['y']),
                  holonomicRotationRadians: s['heading'],
                ),
            ],
          ),
        );
}
