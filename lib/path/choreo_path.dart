import 'dart:convert';
import 'dart:math';

import 'package:file/file.dart';
import 'package:path/path.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/simulator/trajectory_generator.dart';

class ChoreoPath {
  final String name;
  final Trajectory trajectory;

  final FileSystem fs;
  final String choreoDir;

  const ChoreoPath({
    required this.name,
    required this.trajectory,
    required this.fs,
    required this.choreoDir,
  });

  ChoreoPath.fromTrajJson(
      Map<String, dynamic> json, String name, String choreoDir, FileSystem fs)
      : this(
          name: name,
          trajectory: Trajectory(
            states: [
              for (Map<String, dynamic> s in json['samples'])
                TrajectoryState(
                  time: s['timestamp'],
                  position: Point(s['x'], s['y']),
                  holonomicRotationRadians: s['heading'],
                ),
            ],
          ),
          fs: fs,
          choreoDir: choreoDir,
        );

  static Future<List<ChoreoPath>> loadAllPathsInDir(
      String choreoDir, FileSystem fs) async {
    List<ChoreoPath> paths = [];

    Directory dir = fs.directory(choreoDir);

    if (await dir.exists()) {
      List<FileSystemEntity> files = dir.listSync();
      for (FileSystemEntity e in files) {
        if (e.path.endsWith('.traj')) {
          final file = fs.file(e.path);
          String jsonStr = await file.readAsString();

          try {
            Map<String, dynamic> json = jsonDecode(jsonStr);
            String pathName = basenameWithoutExtension(e.path);

            ChoreoPath path =
                ChoreoPath.fromTrajJson(json, pathName, choreoDir, fs);
            paths.add(path);
          } catch (ex, stack) {
            Log.error('Failed to load choreo path', ex, stack);
          }
        }
      }
    }

    return paths;
  }

  List<Point> getPathPositions() {
    return [
      for (TrajectoryState s in trajectory.states) s.position,
    ];
  }
}
