import 'dart:convert';
import 'dart:math';

import 'package:file/file.dart';
import 'package:pathplanner/services/log.dart';
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

  static Future<List<ChoreoPath>> loadAllPathsInProj(
      String projectPath, FileSystem fs) async {
    if (await fs.isFile(projectPath)) {
      try {
        var projFile = fs.file(projectPath);
        String jsonStr = await projFile.readAsString();
        Map<String, dynamic> json = jsonDecode(jsonStr);

        List<ChoreoPath> paths = [];
        for (var entry in (json['paths'] as Map<String, dynamic>).entries) {
          String name = entry.key;
          paths.add(ChoreoPath.fromChorJsonV0_1_1(entry.value, name));
        }
        return paths;
      } catch (ex, stack) {
        Log.error('Failed to load choreo paths', ex, stack);
        return [];
      }
    } else {
      return [];
    }
  }

  List<Point> getPathPositions() {
    return [
      for (TrajectoryState s in trajectory.states) s.position,
    ];
  }
}
