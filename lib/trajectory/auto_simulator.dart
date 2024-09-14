import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/pose2d.dart' as old;
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

class AutoSimulator {
  static PathPlannerTrajectory? simulateAuto(
      List<PathPlannerPath> paths, RobotConfig robotConfig) {
    if (paths.isEmpty) return null;

    List<TrajectoryState> allStates = [];

    old.Pose2d startPose =
        old.Pose2d(position: paths[0].pathPoints[0].position, rotation: 0);
    ChassisSpeeds startSpeeds = const ChassisSpeeds();

    for (PathPlannerPath p in paths) {
      PathPlannerTrajectory simPath = PathPlannerTrajectory(
          path: p,
          startingSpeeds: startSpeeds,
          startingRotation: Rotation2d.fromDegrees(startPose.rotation),
          robotConfig: robotConfig);

      num startTime = allStates.isNotEmpty ? allStates.last.timeSeconds : 0;
      for (TrajectoryState s in simPath.states) {
        s.timeSeconds += startTime;
        allStates.add(s);
      }

      startPose = old.Pose2d(
        position: allStates.last.pose.translation.asPoint(),
        rotation: allStates.last.pose.rotation.getDegrees(),
      );
      startSpeeds = allStates.last.fieldSpeeds;
    }

    return PathPlannerTrajectory.fromStates(allStates);
  }
}
