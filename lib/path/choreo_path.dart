import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

class ChoreoPath {
  final String name;
  final PathPlannerTrajectory trajectory;
  final List<num> eventMarkerTimes;

  final FileSystem fs;
  final String choreoDir;

  const ChoreoPath({
    required this.name,
    required this.trajectory,
    required this.fs,
    required this.choreoDir,
    required this.eventMarkerTimes,
  });

  ChoreoPath.fromTrajJson(
      Map<String, dynamic> json, String name, String choreoDir, FileSystem fs)
      : this(
          name: name,
          trajectory: PathPlannerTrajectory.fromStates(
            [
              for (Map<String, dynamic> s in json['trajectory']['samples'])
                TrajectoryState.pregen(
                  s['t'],
                  ChassisSpeeds(
                    vx: s['vx'],
                    vy: s['vy'],
                    omega: s['omega'],
                  ),
                  Pose2d(Translation2d(s['x'], s['y']),
                      Rotation2d.fromRadians(s['heading'])),
                ),
            ],
          ),
          fs: fs,
          choreoDir: choreoDir,
          eventMarkerTimes: [],
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
          String pathName = basenameWithoutExtension(e.path);
          String jsonStr = await file.readAsString();

          try {
            Map<String, dynamic> json = jsonDecode(jsonStr);

            // Add the full path
            ChoreoPath path =
                ChoreoPath.fromTrajJson(json, pathName, choreoDir, fs);

            if (path.trajectory.states.isEmpty) {
              Log.error(
                  'Failed to load choreo path: $pathName. Path has no trajectory states');
              continue;
            }

            paths.add(path);

            // Add each split
            final splits = (json['trajectory']['splits'] as List<dynamic>)
                .map((e) => (e as num).toInt())
                .toList();

            if (splits.isEmpty || splits.first != 0) {
              splits.insert(0, 0);
            }

            for (int i = 0; i < splits.length; i++) {
              String name = '$pathName.$i';

              int startIdx = splits[i];
              int endIdx;
              if (i == splits.length - 1) {
                endIdx = path.trajectory.states.length;
              } else {
                endIdx = splits[i + 1];
              }

              num startTime = path.trajectory.states[startIdx].timeSeconds;
              final splitStates = [
                for (TrajectoryState s
                    in path.trajectory.states.sublist(startIdx, endIdx))
                  s.copyWithTime(s.timeSeconds - startTime)
              ];
              final splitTraj = PathPlannerTrajectory.fromStates(splitStates);
              final splitPath = ChoreoPath(
                name: name,
                trajectory: splitTraj,
                fs: fs,
                choreoDir: choreoDir,
                eventMarkerTimes: [],
              );
              paths.add(splitPath);
            }
          } catch (ex, stack) {
            Log.error('Failed to load choreo path: $pathName', ex, stack);
          }
        }
      }
    }

    return paths;
  }

  List<Translation2d> get pathPositions => [
        for (TrajectoryState s in trajectory.states) s.pose.translation,
      ];
}
