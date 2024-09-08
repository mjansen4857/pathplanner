import 'dart:math';

import 'package:file/memory.dart';
import 'package:pathplanner/path/constraints_zone.dart';
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
  static const double pathResolution = 0.025;

  static PathPlannerTrajectory? simulateAuto(List<PathPlannerPath> paths,
      old.Pose2d? startingPose, RobotConfig robotConfig) {
    if (paths.isEmpty) return null;

    List<TrajectoryState> allStates = [];

    old.Pose2d startPose = startingPose ??
        old.Pose2d(position: paths[0].pathPoints[0].position, rotation: 0);
    ChassisSpeeds startSpeeds = const ChassisSpeeds();

    for (PathPlannerPath p in paths) {
      PathPlannerPath replanned =
          _replanPathIfNeeded(p, startPose, startSpeeds);
      PathPlannerTrajectory simPath = PathPlannerTrajectory(
          path: replanned,
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

  static PathPlannerPath _replanPathIfNeeded(PathPlannerPath path,
      old.Pose2d startingPose, ChassisSpeeds startingSpeeds) {
    num linearVel = sqrt(pow(startingSpeeds.vx, 2) + pow(startingSpeeds.vy, 2));
    num currentHeading = atan2(startingSpeeds.vy, startingSpeeds.vx);
    var p1 = path.pathPoints[0].position;
    var p2 = path.pathPoints[1].position;
    num targetHeading = atan2(p2.y - p1.y, p2.x - p1.x);
    num headingError = (currentHeading - targetHeading).abs();
    bool onHeading =
        linearVel < 0.25 || GeometryUtil.toDegrees(headingError) < 30;

    if (startingPose.position.distanceTo(path.pathPoints.first.position) <=
            0.1 &&
        onHeading) {
      return path;
    }

    Point? robotNextControl;
    if (linearVel > 0.1) {
      num stoppingDistance =
          pow(linearVel, 2) / (2 * path.globalConstraints.maxAcceleration);

      num headingRadians = atan2(startingSpeeds.vy, startingSpeeds.vx);
      robotNextControl = startingPose.position +
          Point(stoppingDistance * cos(headingRadians),
              stoppingDistance * sin(headingRadians));
    }

    int closestPointIdx = 0;
    Point comparePoint = robotNextControl ?? startingPose.position;
    num closestDist =
        comparePoint.distanceTo(path.pathPoints[closestPointIdx].position);

    for (int i = 1; i < path.pathPoints.length; i++) {
      num d = comparePoint.distanceTo(path.pathPoints[i].position);

      if (d < closestDist) {
        closestPointIdx = i;
        closestDist = d;
      }
    }

    if (closestPointIdx == path.pathPoints.length - 1) {
      num headingRadians = atan2(
          path.pathPoints.last.position.y - comparePoint.y,
          path.pathPoints.last.position.x - comparePoint.x);

      robotNextControl ??= startingPose.position +
          Point(closestDist / 3.0 * cos(headingRadians),
              closestDist / 3.0 * sin(headingRadians));

      num endPrevControlHeading = atan2(
          path.pathPoints.last.position.y - robotNextControl.y,
          path.pathPoints.last.position.x - robotNextControl.x);

      Point endPrevControl = path.pathPoints.last.position -
          Point(closestDist / 3.0 * cos(endPrevControlHeading),
              closestDist / 3.0 * sin(endPrevControlHeading));

      // Throw out rotation targets, event markers, and constraint zones since we are skipping all
      // of the path
      return PathPlannerPath(
        name: '',
        waypoints: [
          Waypoint(
            anchor: startingPose.position,
            nextControl: robotNextControl,
          ),
          Waypoint(
            prevControl: endPrevControl,
            anchor: path.pathPoints.last.position,
          ),
        ],
        globalConstraints: path.globalConstraints,
        goalEndState: path.goalEndState,
        constraintZones: path.constraintZones,
        rotationTargets: path.rotationTargets,
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
      );
    } else if ((closestPointIdx == 0 && robotNextControl == null) ||
        ((closestDist -
                        startingPose.position
                            .distanceTo(path.pathPoints[0].position))
                    .abs() <=
                0.25 &&
            linearVel < 0.1)) {
      num distToStart =
          startingPose.position.distanceTo(path.pathPoints[0].position);

      num heading = atan2(
          path.pathPoints[0].position.y - startingPose.position.y,
          path.pathPoints[0].position.x - startingPose.position.x);
      robotNextControl = startingPose.position +
          Point(distToStart / 3.0 * cos(heading),
              distToStart / 3.0 * sin(heading));

      num joinHeading = atan2(
          path.waypoints[0].anchor.y - path.waypoints[0].nextControl!.y,
          path.waypoints[0].anchor.x - path.waypoints[0].nextControl!.x);
      Point joinPrevControl = path.pathPoints[0].position +
          Point(distToStart / 2.0 * cos(joinHeading),
              distToStart / 2.0 * sin(joinHeading));

      List<Waypoint> replannedWaypoints = [
        Waypoint(
          anchor: startingPose.position,
          nextControl: robotNextControl,
        ),
        Waypoint(
            prevControl: joinPrevControl,
            anchor: path.waypoints[0].anchor,
            nextControl: path.waypoints[0].nextControl),
        ...path.waypoints.getRange(1, path.waypoints.length)
      ];

      // keep all rotations, markers, and zones and increment waypoint pos by 1
      return PathPlannerPath(
        name: '',
        waypoints: replannedWaypoints,
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
      );
    }

    int joinAnchorIdx = path.pathPoints.length - 1;
    for (int i = closestPointIdx; i < path.pathPoints.length; i++) {
      if (path.pathPoints[i].distanceAlongPath >=
          path.pathPoints[closestPointIdx].distanceAlongPath + closestDist) {
        joinAnchorIdx = i;
        break;
      }
    }

    Point joinPrevControl = path.pathPoints[closestPointIdx].position;
    Point joinAnchor = path.pathPoints[joinAnchorIdx].position;

    if (robotNextControl == null) {
      num robotToJoinDelta = startingPose.position.distanceTo(joinAnchor);
      num heading = atan2(joinPrevControl.y - startingPose.position.y,
          joinPrevControl.x - startingPose.position.x);
      robotNextControl = startingPose.position +
          Point(robotToJoinDelta / 3.0 * cos(heading),
              robotToJoinDelta / 3.0 * sin(heading));
    }

    if (joinAnchorIdx == path.pathPoints.length - 1) {
      // Throw out rotation targets, event markers, and constraint zones since we are skipping all
      // of the path
      return PathPlannerPath(
        name: '',
        waypoints: [
          Waypoint(
            anchor: startingPose.position,
            nextControl: robotNextControl,
          ),
          Waypoint(
            prevControl: joinPrevControl,
            anchor: joinAnchor,
          ),
        ],
        globalConstraints: path.globalConstraints,
        goalEndState: path.goalEndState,
        constraintZones: path.constraintZones,
        rotationTargets: path.rotationTargets,
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
      );
    }

    int nextWaypointIdx = ((joinAnchorIdx + 1) * pathResolution).ceil();
    double waypointDelta =
        joinAnchor.distanceTo(path.waypoints[nextWaypointIdx].anchor);

    num joinHeading = atan2(
        joinAnchor.y - joinPrevControl.y, joinAnchor.x - joinPrevControl.x);
    Point joinNextControl = joinAnchor +
        Point(waypointDelta / 3.0 * cos(joinHeading),
            waypointDelta / 3.0 * sin(joinHeading));

    num nextWaypointHeading;
    if (nextWaypointIdx == path.waypoints.length - 1) {
      nextWaypointHeading = atan2(
          path.waypoints.last.prevControl!.y - path.waypoints.last.anchor.y,
          path.waypoints.last.prevControl!.x - path.waypoints.last.anchor.x);
    } else {
      nextWaypointHeading = atan2(
          path.waypoints[nextWaypointIdx].anchor.y -
              path.waypoints[nextWaypointIdx].nextControl!.y,
          path.waypoints[nextWaypointIdx].anchor.x -
              path.waypoints[nextWaypointIdx].nextControl!.x);
    }

    Point nextWaypointPrevControl = path.waypoints[nextWaypointIdx].anchor +
        Point(max(waypointDelta / 3.0, 0.15) * cos(nextWaypointHeading),
            max(waypointDelta / 3.0, 0.15) * sin(nextWaypointHeading));

    List<Waypoint> replannedWaypoints = [
      Waypoint(
        anchor: startingPose.position,
        nextControl: robotNextControl,
      ),
      Waypoint(
        prevControl: joinPrevControl,
        anchor: joinAnchor,
        nextControl: joinNextControl,
      ),
      Waypoint(
        prevControl: nextWaypointPrevControl,
        anchor: path.waypoints[nextWaypointIdx].anchor,
        nextControl: path.waypoints[nextWaypointIdx].nextControl,
      ),
      if (nextWaypointIdx < path.waypoints.length)
        ...path.waypoints.getRange(nextWaypointIdx + 1, path.waypoints.length),
    ];

    num segment1Length = 0;
    Point lastSegment1Pos = startingPose.position;
    num segment2Length = 0;
    Point lastSegment2Pos = joinAnchor;

    for (double t = pathResolution; t < 1.0; t += pathResolution) {
      Point p1 = GeometryUtil.cubicLerp(startingPose.position, robotNextControl,
          joinPrevControl, joinAnchor, t);
      Point p2 = GeometryUtil.cubicLerp(joinAnchor, joinNextControl,
          nextWaypointPrevControl, path.waypoints[nextWaypointIdx].anchor, t);

      segment1Length += lastSegment1Pos.distanceTo(p1);
      segment2Length += lastSegment2Pos.distanceTo(p2);

      lastSegment1Pos = p1;
      lastSegment2Pos = p2;
    }

    double segment1Pct = segment1Length / (segment1Length + segment2Length);

    List<RotationTarget> mappedTargets = [];
    List<ConstraintsZone> mappedZones = [];

    for (RotationTarget t in path.rotationTargets) {
      if (t.waypointRelativePos >= nextWaypointIdx) {
        mappedTargets.add(RotationTarget(
            waypointRelativePos: t.waypointRelativePos - nextWaypointIdx + 2,
            rotationDegrees: t.rotationDegrees));
      } else if (t.waypointRelativePos >= nextWaypointIdx - 1) {
        num pct = t.waypointRelativePos - (nextWaypointIdx - 1);
        mappedTargets.add(RotationTarget(
            waypointRelativePos: _mapPct(pct, segment1Pct),
            rotationDegrees: t.rotationDegrees));
      }
    }

    for (ConstraintsZone z in path.constraintZones) {
      num minPos = 0;
      num maxPos = 0;

      if (z.minWaypointRelativePos >= nextWaypointIdx) {
        minPos = z.minWaypointRelativePos - nextWaypointIdx + 2;
      } else if (z.minWaypointRelativePos >= nextWaypointIdx - 1) {
        num pct = z.minWaypointRelativePos - (nextWaypointIdx - 1);
        minPos = _mapPct(pct, segment1Pct);
      }

      if (z.maxWaypointRelativePos >= nextWaypointIdx) {
        maxPos = z.maxWaypointRelativePos - nextWaypointIdx + 2;
      } else if (z.maxWaypointRelativePos >= nextWaypointIdx - 1) {
        double pct = z.maxWaypointRelativePos - (nextWaypointIdx - 1);
        maxPos = _mapPct(pct, segment1Pct);
      }

      if (maxPos > 0) {
        mappedZones.add(ConstraintsZone(
            minWaypointRelativePos: minPos,
            maxWaypointRelativePos: maxPos,
            constraints: z.constraints));
      }
    }

    // Throw out everything before nextWaypointIdx - 1, map everything from nextWaypointIdx -
    // 1 to nextWaypointIdx on to the 2 joining segments (waypoint rel pos within old segment = %
    // along distance of both new segments)
    return PathPlannerPath(
      name: '',
      waypoints: replannedWaypoints,
      globalConstraints: path.globalConstraints,
      goalEndState: path.goalEndState,
      constraintZones: mappedZones,
      rotationTargets: mappedTargets,
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
    );
  }

  static num _mapPct(num pct, num seg1Pct) {
    num mappedPct;
    if (pct <= seg1Pct) {
      mappedPct = pct / seg1Pct;
    } else {
      mappedPct = 1 + ((pct - seg1Pct) / (1.0 - seg1Pct));
    }

    return (mappedPct * (1.0 / pathResolution)).round() /
        (1.0 / pathResolution);
  }
}
