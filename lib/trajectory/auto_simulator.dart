import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

class AutoSimulator {
  static PathPlannerTrajectory? simulateAuto(
      List<PathPlannerPath> paths, RobotConfig robotConfig) {
    if (paths.isEmpty) return null;

    List<TrajectoryState> allStates = [];

    Pose2d startPose = Pose2d(
        paths[0].pathPoints[0].position, paths[0].idealStartingState.rotation);
    ChassisSpeeds startSpeeds = const ChassisSpeeds();

    for (PathPlannerPath p in paths) {
      PathPlannerTrajectory simPath = PathPlannerTrajectory(
          path: p,
          startingSpeeds: startSpeeds,
          startingRotation: startPose.rotation,
          robotConfig: robotConfig);

      num startTime = allStates.isNotEmpty ? allStates.last.timeSeconds : 0;
      for (TrajectoryState s in simPath.states) {
        s.timeSeconds += startTime;
        allStates.add(s);
      }

      startPose = Pose2d(
        allStates.last.pose.translation,
        allStates.last.pose.rotation,
      );
      startSpeeds = allStates.last.fieldSpeeds;
    }

    return PathPlannerTrajectory.fromStates(allStates);
  }
}
