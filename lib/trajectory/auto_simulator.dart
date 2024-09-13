import 'dart:math';

import 'package:file/memory.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/geometry_util.dart';
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
      List<PathPlannerPath> replanned =
          _replanPathIfNeeded(p, startPose, startSpeeds);
      for (PathPlannerPath p2 in replanned) {
        PathPlannerTrajectory simPath = PathPlannerTrajectory(
            path: p2,
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
    }

    return PathPlannerTrajectory.fromStates(allStates);
  }

  static List<PathPlannerPath> _replanPathIfNeeded(PathPlannerPath path,
      old.Pose2d startingPose, ChassisSpeeds startingSpeeds) {
    num linearVel = sqrt(pow(startingSpeeds.vx, 2) + pow(startingSpeeds.vy, 2));
    num currentHeading = atan2(startingSpeeds.vy, startingSpeeds.vx);
    var p1 = path.pathPoints[0].position;
    var p2 = path.pathPoints[1].position;
    num targetHeading = atan2(p2.y - p1.y, p2.x - p1.x);
    num headingError = (currentHeading - targetHeading).abs();
    bool onHeading =
        linearVel < 0.25 || GeometryUtil.toDegrees(headingError) < 30;
    double dist =
        startingPose.position.distanceTo(path.pathPoints.first.position);

    if (dist <= 0.25 && onHeading) {
      return [path];
    }

    // Path needs to be replanned
    Point startAnchor = startingPose.position;
    Point endAnchor = path.pathPoints.first.position;

    Point startControl;
    if (linearVel >= 0.25) {
      num stoppingDistance =
          pow(linearVel, 2) / (2 * path.globalConstraints.maxAcceleration);

      num headingRadians = atan2(startingSpeeds.vy, startingSpeeds.vx);
      startControl = startAnchor +
          Point(stoppingDistance * cos(headingRadians),
              stoppingDistance * sin(headingRadians));
    } else {
      // We are not moving, just point towards next path start point
      num headingRadians = atan2(
          path.pathPoints.first.position.y - startAnchor.y,
          path.pathPoints.first.position.x - startAnchor.x);

      startControl = startAnchor +
          Point((dist / 3.0) * cos(headingRadians),
              (dist / 3.0) * sin(headingRadians));
    }

    Rotation2d pathStartHeading =
        Rotation2d.fromRadians(path.waypoints.first.getHeadingRadians());
    Rotation2d angleToPathStart = Rotation2d.fromRadians(atan2(
        path.pathPoints.first.position.y - startAnchor.y,
        path.pathPoints.first.position.x - startAnchor.x));

    if ((angleToPathStart - pathStartHeading).getDegrees().abs() <= 90) {
      // We dont need to stop, set the end control based on the path start heading

      Rotation2d heading = pathStartHeading + Rotation2d.fromDegrees(180);
      Point endControl = endAnchor +
          Point(
              (dist / 3.0) * heading.getCos(), (dist / 3.0) * heading.getSin());

      List<Waypoint> waypoints = [
        Waypoint(
          anchor: startAnchor,
          nextControl: startControl,
        ),
        Waypoint(
            prevControl: endControl,
            anchor: endAnchor,
            nextControl: path.waypoints[0].nextControl),
        ...path.waypoints.getRange(1, path.waypoints.length)
      ];

      return [
        PathPlannerPath(
          name: '',
          waypoints: waypoints,
          globalConstraints: path.globalConstraints,
          goalEndState: path.goalEndState,
          constraintZones: path.constraintZones
              .map((e) => ConstraintsZone(
                  constraints: e.constraints,
                  minWaypointRelativePos: e.minWaypointRelativePos + 1,
                  maxWaypointRelativePos: e.maxWaypointRelativePos + 1))
              .toList(),
          rotationTargets: path.rotationTargets
              .map((e) => RotationTarget(
                  waypointRelativePos: e.waypointRelativePos + 1,
                  rotationDegrees: e.rotationDegrees))
              .toList(),
          eventMarkers: [],
          pathDir: '',
          fs: MemoryFileSystem(),
          reversed: path.reversed,
          folder: null,
          idealStartingState: IdealStartingState(
            velocity: linearVel,
            rotation: startingPose.rotation,
          ),
          useDefaultConstraints: path.useDefaultConstraints,
        )
      ];
    } else {
      // We need to stop, replan as two paths
      Rotation2d heading = angleToPathStart + Rotation2d.fromDegrees(180);
      Point endControl = endAnchor +
          Point(
              (dist / 3.0) * heading.getCos(), (dist / 3.0) * heading.getSin());

      List<Waypoint> waypoints = [
        Waypoint(
          anchor: startAnchor,
          nextControl: startControl,
        ),
        Waypoint(
          prevControl: endControl,
          anchor: endAnchor,
        ),
      ];

      return [
        PathPlannerPath(
          name: '',
          waypoints: waypoints,
          globalConstraints: path.globalConstraints,
          goalEndState: GoalEndState(
            velocity: path.idealStartingState.velocity,
            rotation: path.idealStartingState.rotation,
          ),
          constraintZones: [],
          rotationTargets: [],
          eventMarkers: [],
          pathDir: '',
          fs: MemoryFileSystem(),
          reversed: path.reversed,
          folder: null,
          idealStartingState: IdealStartingState(
            velocity: linearVel,
            rotation: startingPose.rotation,
          ),
          useDefaultConstraints: path.useDefaultConstraints,
        ),
        path
      ];
    }
  }
}
