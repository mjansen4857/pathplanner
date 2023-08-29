import 'dart:math';

import 'package:file/memory.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/simulator/chassis_speeds.dart';
import 'package:pathplanner/services/simulator/rotation_controller.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/math_util.dart';
import 'package:pathplanner/util/pose2d.dart';

class TrajectoryGenerator {
  static Trajectory? simulateAuto(
      List<PathPlannerPath> paths, Pose2d? startingPose) {
    if (paths.isEmpty) return null;

    List<TrajectoryState> allStates = [];

    Pose2d startPose = startingPose ??
        Pose2d(position: paths[0].pathPoints[0].position, rotation: 0);
    ChassisSpeeds startSpeeds = ChassisSpeeds();

    for (PathPlannerPath p in paths) {
      PathPlannerPath replanned =
          _replanPathIfNeeded(p, startPose, startSpeeds);
      Trajectory simPath = Trajectory.simulate(replanned, startSpeeds,
          startingRotationRadians: GeometryUtil.toRadians(startPose.rotation));

      num startTime = allStates.isNotEmpty ? allStates.last.time : 0;
      for (TrajectoryState s in simPath.states) {
        s.time += startTime;
        allStates.add(s);
      }

      startPose = Pose2d(
        position: allStates.last.position,
        rotation:
            GeometryUtil.toDegrees(allStates.last.holonomicRotationRadians),
      );
      startSpeeds = ChassisSpeeds(
        vx: allStates.last.velocity * cos(allStates.last.headingRadians),
        vy: allStates.last.velocity * sin(allStates.last.headingRadians),
      );
    }

    return Trajectory(states: allStates);
  }

  static PathPlannerPath _replanPathIfNeeded(
      PathPlannerPath path, Pose2d startingPose, ChassisSpeeds startingSpeeds) {
    num linearVel = sqrt(pow(startingSpeeds.vx, 2) + pow(startingSpeeds.vy, 2));
    if (startingPose.position.distanceTo(path.pathPoints.first.position) <=
            0.1 &&
        linearVel < 0.1) {
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
          path.waypoints[0].anchor.y - path.waypoints[1].nextControl!.y,
          path.waypoints[0].anchor.x - path.waypoints[1].nextControl!.x);
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

    if (joinAnchorIdx == path.pathPoints.length) {
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

class Trajectory {
  final List<TrajectoryState> states;

  Trajectory({required this.states});

  // Just using default values for the kinematics stuff. It will be a good enough approximation
  Trajectory.simulate(PathPlannerPath path, ChassisSpeeds startingSpeeds,
      {num maxModuleSpeed = 4.5,
      num driveBaseRadius = 0.425,
      num startingRotationRadians = 0})
      : states = _generateStates(path, startingSpeeds) {
    _simulateRotation(startingRotationRadians, maxModuleSpeed, driveBaseRadius);
  }

  TrajectoryState sample(num time) {
    if (time <= states.first.time) return states.first;
    if (time >= states.last.time) return states.last;

    int low = 1;
    int high = states.length - 1;

    while (low != high) {
      int mid = ((low + high) / 2).floor();
      if (states[mid].time < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    TrajectoryState sample = states[low];
    TrajectoryState prevSample = states[low - 1];

    if ((sample.time - prevSample.time).abs() < 1E-3) return sample;

    return prevSample.interpolate(
        sample, (time - prevSample.time) / (sample.time - prevSample.time));
  }

  void _simulateRotation(
      num startingRotationRadians, num maxModuleSpeed, num driveBaseRadius) {
    num mpsToRps = 1.0 / driveBaseRadius;

    RotationController controller = RotationController(
        setpoint: State(position: startingRotationRadians, velocity: 0));

    states.first.holonomicRotationRadians = startingRotationRadians;

    for (int i = 1; i < states.length; i++) {
      num angVelConstraint =
          GeometryUtil.toRadians(states[i].constraints.maxAngularVelocity);

      // Approximation of available module speed to do rotation with
      num maxAngVelModule =
          max(0, maxModuleSpeed - states[i].velocity) * mpsToRps;
      num maxAngVel = min(angVelConstraint, maxAngVelModule);

      num dt = states[i].time - states[i - 1].time;
      num rot = controller.calculate(
          states[i - 1].holonomicRotationRadians,
          states[i].holonomicRotationRadians,
          maxAngVel,
          GeometryUtil.toRadians(states[i].constraints.maxAngularAcceleration),
          dt);

      states[i].holonomicRotationRadians = MathUtil.inputModulus(rot, -pi, pi);
    }
  }

  static int _getNextRotationTargetIdx(
      PathPlannerPath path, int startingIndex) {
    int idx = path.pathPoints.length - 1;

    for (int i = startingIndex; i < path.pathPoints.length - 2; i++) {
      if (path.pathPoints[i].holonomicRotation != null) {
        idx = i;
        break;
      }
    }

    return idx;
  }

  static List<TrajectoryState> _generateStates(
      PathPlannerPath path, ChassisSpeeds startingSpeeds) {
    List<TrajectoryState> states = [];

    num startVel = sqrt(pow(startingSpeeds.vx, 2) + pow(startingSpeeds.vy, 2));

    int nextRotationTargetIdx = _getNextRotationTargetIdx(path, 0);

    // Initial pass. Creates all states and handles linear acceleration
    for (int i = 0; i < path.pathPoints.length; i++) {
      TrajectoryState state = TrajectoryState();

      PathConstraints constraints = path.pathPoints[i].constraints;
      state.constraints = constraints;

      if (i > nextRotationTargetIdx) {
        nextRotationTargetIdx = _getNextRotationTargetIdx(path, i);
      }

      state.holonomicRotationRadians = GeometryUtil.toRadians(
          path.pathPoints[nextRotationTargetIdx].holonomicRotation!);

      state.position = path.pathPoints[i].position;

      if (i == path.pathPoints.length - 1) {
        state.headingRadians = states[states.length - 1].headingRadians;
        state.deltaPos = path.pathPoints[i].distanceAlongPath -
            path.pathPoints[i - 1].distanceAlongPath;
        state.velocity = path.goalEndState.velocity;
      } else if (i == 0) {
        Point delta = path.pathPoints[i + 1].position - state.position;
        state.headingRadians = atan2(delta.y, delta.x);
        state.deltaPos = 0;
        state.velocity = startVel;
      } else {
        Point delta = path.pathPoints[i + 1].position - state.position;
        state.headingRadians = atan2(delta.y, delta.x);
        state.deltaPos = path.pathPoints[i + 1].distanceAlongPath -
            path.pathPoints[i].distanceAlongPath;

        num v0 = states[states.length - 1].velocity;
        num vMax = sqrt(
            (pow(v0, 2) + (2 * constraints.maxAcceleration * state.deltaPos))
                .abs());
        state.velocity = min(vMax, path.pathPoints[i].maxV);
      }

      states.add(state);
    }

    // Second pass. Handles linear deceleration
    for (int i = states.length - 2; i > 1; i--) {
      PathConstraints constraints = states[i].constraints;

      num v0 = states[i + 1].velocity;

      num vMax = sqrt(pow(v0, 2) +
          (2 * constraints.maxAcceleration * states[i + 1].deltaPos).abs());
      states[i].velocity = min(vMax, states[i].velocity);
    }

    // Final pass. Calculates time, linear acceleration, and angular velocity
    num time = 0;
    states.first.time = 0;

    for (int i = 1; i < states.length; i++) {
      num v0 = states[i - 1].velocity;
      num v = states[i].velocity;
      num dt = (2 * states[i].deltaPos) / (v + v0);

      time += dt;
      states[i].time = time;
    }

    return states;
  }
}

class TrajectoryState {
  num time = 0;
  num velocity = 0;

  Point position = const Point(0, 0);
  num headingRadians = 0;

  num holonomicRotationRadians = 0;
  PathConstraints constraints = PathConstraints();

  num deltaPos = 0;

  TrajectoryState();

  TrajectoryState interpolate(TrajectoryState endVal, num t) {
    TrajectoryState lerpedState = TrajectoryState();

    lerpedState.time = GeometryUtil.numLerp(time, endVal.time, t);
    num deltaT = lerpedState.time - time;

    if (deltaT < 0) {
      return endVal.interpolate(this, 1 - t);
    }

    lerpedState.velocity = GeometryUtil.numLerp(velocity, endVal.velocity, t);
    lerpedState.position = GeometryUtil.pointLerp(position, endVal.position, t);
    lerpedState.headingRadians =
        GeometryUtil.rotationLerp(headingRadians, endVal.headingRadians, t, pi);
    lerpedState.deltaPos = GeometryUtil.numLerp(deltaPos, endVal.deltaPos, t);
    lerpedState.holonomicRotationRadians = GeometryUtil.rotationLerp(
        holonomicRotationRadians, endVal.holonomicRotationRadians, t, pi);

    if (t < 0.5) {
      lerpedState.constraints = constraints;
    } else {
      lerpedState.constraints = endVal.constraints;
    }

    return lerpedState;
  }
}
