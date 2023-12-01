from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Final, List
from wpimath.geometry import Rotation2d, Translation2d, Pose2d
from wpimath.kinematics import ChassisSpeeds
import wpimath.units as units
from wpimath import inputModulus
from commands2 import Command
import commands2.cmd as cmd
from .geometry_util import decimal_range, cubicLerp, calculateRadius
from .auto import CommandUtil
from wpilib import getDeployDirectory
import os
import json

RESOLUTION: Final[float] = 0.05


@dataclass(frozen=True)
class PathConstraints:
    maxVelocityMps: float
    maxAccelerationMpsSq: float
    maxAngularVelocityRps: float
    maxAngularAccelerationRpsSq: float

    @staticmethod
    def fromJson(json_dict: dict) -> PathConstraints:
        maxVel = float(json_dict['maxVelocity'])
        maxAccel = float(json_dict['maxAcceleration'])
        maxAngularVel = float(json_dict['maxAngularVelocity'])
        maxAngularAccel = float(json_dict['maxAngularAcceleration'])

        return PathConstraints(
            maxVel,
            maxAccel,
            units.degreesToRadians(maxAngularVel),
            units.degreesToRadians(maxAngularAccel))

    def __eq__(self, other):
        return (isinstance(other, PathConstraints)
                and other.maxVelocityMps == self.maxVelocityMps
                and other.maxAccelerationMpsSq == self.maxAccelerationMpsSq
                and other.maxAngularVelocityRps == self.maxAngularVelocityRps
                and other.maxAngularAccelerationRpsSq == self.maxAngularAccelerationRpsSq)


@dataclass(frozen=True)
class GoalEndState:
    velocity: float
    rotation: Rotation2d
    rotateFast: bool = False

    @staticmethod
    def fromJson(json_dict: dict) -> GoalEndState:
        vel = float(json_dict['velocity'])
        deg = float(json_dict['rotation'])

        rotateFast = False
        if 'rotateFast' in json_dict:
            rotateFast = bool(json_dict['rotateFast'])

        return GoalEndState(vel, Rotation2d.fromDegrees(deg), rotateFast)

    def __eq__(self, other):
        return (isinstance(other, GoalEndState)
                and other.velocity == self.velocity
                and other.rotation == self.rotation
                and other.rotateFast == self.rotateFast)


@dataclass(frozen=True)
class ConstraintsZone:
    minWaypointPos: float
    maxWaypointPos: float
    constraints: PathConstraints

    @staticmethod
    def fromJson(json_dict: dict) -> ConstraintsZone:
        minPos = float(json_dict['minWaypointRelativePos'])
        maxPos = float(json_dict['maxWaypointRelativePos'])
        constraints = PathConstraints.fromJson(json_dict['constraints'])

        return ConstraintsZone(minPos, maxPos, constraints)

    def isWithinZone(self, t: float) -> bool:
        return self.minWaypointPos <= t <= self.maxWaypointPos

    def overlapsRange(self, min_pos: float, max_pos: float) -> bool:
        return max(min_pos, self.minWaypointPos) <= min(max_pos, self.maxWaypointPos)

    def forSegmentIndex(self, segment_index: int) -> ConstraintsZone:
        return ConstraintsZone(self.minWaypointPos - segment_index, self.maxWaypointPos - segment_index,
                               self.constraints)

    def __eq__(self, other):
        return (isinstance(other, ConstraintsZone)
                and other.minWaypointPos == self.minWaypointPos
                and other.maxWaypointPos == self.maxWaypointPos
                and other.constraints == self.constraints)


@dataclass(frozen=True)
class RotationTarget:
    waypointRelativePosition: float
    target: Rotation2d
    rotateFast: bool = False

    @staticmethod
    def fromJson(json_dict: dict) -> RotationTarget:
        pos = float(json_dict['waypointRelativePos'])
        deg = float(json_dict['rotationDegrees'])

        rotateFast = False
        if 'rotateFast' in json_dict:
            rotateFast = bool(json_dict['rotateFast'])

        return RotationTarget(pos, Rotation2d.fromDegrees(deg), rotateFast)

    def forSegmentIndex(self, segment_index: int) -> RotationTarget:
        return RotationTarget(self.waypointRelativePosition - segment_index, self.target, self.rotateFast)

    def __eq__(self, other):
        return (isinstance(other, RotationTarget)
                and other.waypointRelativePosition == self.waypointRelativePosition
                and other.target == self.target
                and other.rotateFast == self.rotateFast)


@dataclass
class EventMarker:
    waypointRelativePos: float
    command: Command
    minimumTriggerDistance: float = 0.5
    markerPos: Translation2d = None
    lastRobotPos: Translation2d = None

    @staticmethod
    def fromJson(json_dict: dict) -> EventMarker:
        pos = float(json_dict['waypointRelativePos'])
        command = CommandUtil.commandFromJson(json_dict['command'])
        return EventMarker(pos, command)

    def reset(self, robot_pose: Pose2d) -> None:
        self.lastRobotPos = robot_pose.translation()

    def shouldTrigger(self, robot_pose: Pose2d) -> bool:
        if self.lastRobotPos is None or self.markerPos is None:
            self.lastRobotPos = robot_pose.translation()
            return False

        distanceToMarker = robot_pose.translation().distance(self.markerPos)
        trigger = self.minimumTriggerDistance >= distanceToMarker > self.lastRobotPos.distance(self.markerPos)
        self.lastRobotPos = robot_pose.translation()
        return trigger

    def __eq__(self, other):
        return (isinstance(other, EventMarker)
                and other.waypointRelativePos == self.waypointRelativePos
                and other.minimumTriggerDistance == self.minimumTriggerDistance
                and other.command == self.command)


@dataclass
class PathPoint:
    position: Translation2d
    rotationTarget: RotationTarget
    constraints: PathConstraints = None
    distanceAlongPath: float = 0.0
    curveRadius: float = 0.0
    maxV: float = float('inf')

    def __eq__(self, other):
        return (isinstance(other, PathPoint)
                and other.position == self.position
                and other.holonomicRotation == self.rotationTarget
                and other.constraints == self.constraints
                and other.distanceAlongPath == self.distanceAlongPath
                and other.curveRadius == self.curveRadius
                and other.maxV == self.maxV)


class PathSegment:
    segmentPoints: List[PathPoint]

    def __init__(self, p1: Translation2d, p2: Translation2d, p3: Translation2d, p4: Translation2d,
                 target_holonomic_rotations: List[RotationTarget] = [], constraint_zones: List[ConstraintsZone] = [],
                 end_segment: bool = False):
        self.segmentPoints = []

        for t in decimal_range(0.0, 1.0, RESOLUTION):
            holonomicRotation = None

            if len(target_holonomic_rotations) > 0:
                if math.fabs(target_holonomic_rotations[0].waypointRelativePosition - t) <= math.fabs(
                        target_holonomic_rotations[0].waypointRelativePosition - min(t + RESOLUTION, 1.0)):
                    holonomicRotation = target_holonomic_rotations.pop(0)

            currentZone = self._findConstraintsZone(constraint_zones, t)

            if currentZone is not None:
                self.segmentPoints.append(
                    PathPoint(cubicLerp(p1, p2, p3, p4, t), holonomicRotation, currentZone.constraints))
            else:
                self.segmentPoints.append(PathPoint(cubicLerp(p1, p2, p3, p4, t), holonomicRotation))

        if end_segment:
            holonomicRotation = target_holonomic_rotations.pop(0) if len(
                target_holonomic_rotations) > 0 else None
            self.segmentPoints.append(PathPoint(cubicLerp(p1, p2, p3, p4, 1.0), holonomicRotation))

    @staticmethod
    def _findConstraintsZone(zones: List[ConstraintsZone], t: float) -> ConstraintsZone | None:
        for zone in zones:
            if zone.isWithinZone(t):
                return zone
        return None


class PathPlannerPath:
    _bezierPoints: List[Translation2d]
    _rotationTargets: List[RotationTarget]
    _constraintZones: List[ConstraintsZone]
    _eventMarkers: List[EventMarker]
    _globalConstraints: PathConstraints
    _goalEndState: GoalEndState
    _allPoints: List[PathPoint]
    _reversed: bool
    _previewStartingRotation: Rotation2d

    def __init__(self, bezier_points: List[Translation2d], constraints: PathConstraints, goal_end_state: GoalEndState,
                 holonomic_rotations: List[RotationTarget] = [], constraint_zones: List[ConstraintsZone] = [],
                 event_markers: List[EventMarker] = [], is_reversed: bool = False,
                 preview_starting_rotation: Rotation2d = Rotation2d()):
        self._bezierPoints = bezier_points
        self._rotationTargets = holonomic_rotations
        self._constraintZones = constraint_zones
        self._eventMarkers = event_markers
        self._globalConstraints = constraints
        self._goalEndState = goal_end_state
        self._reversed = is_reversed
        self._allPoints = PathPlannerPath._createPath(self._bezierPoints, self._rotationTargets, self._constraintZones)
        self._previewStartingRotation = preview_starting_rotation

        self._precalcValues()

    @staticmethod
    def fromPathPoints(path_points: List[PathPoint], constraints: PathConstraints,
                       goal_end_state: GoalEndState) -> PathPlannerPath:
        path = PathPlannerPath([], constraints, goal_end_state)
        path._allPoints = path_points
        path._precalcValues()

        return path

    @staticmethod
    def fromPathFile(path_name: str) -> PathPlannerPath:
        filePath = os.path.join(getDeployDirectory(), 'pathplanner', 'paths', path_name + '.path')

        with open(filePath, 'r') as f:
            pathJson = json.loads(f.read())
            return PathPlannerPath._fromJson(pathJson)

    @staticmethod
    def bezierFromPoses(poses: List[Pose2d]) -> List[Translation2d]:
        if len(poses) < 2:
            raise ValueError('Not enough poses')

        bezierPoints = []

        # First pose
        bezierPoints.append(poses[0].translation())
        bezierPoints.append(
            poses[0].translation() + Translation2d(poses[0].translation().distance(poses[1].translation()) / 3.0,
                                                   poses[0].rotation()))

        # Middle poses
        for i in range(1, len(poses) - 1):
            anchor = poses[i].translation()

            # Prev control
            bezierPoints.append(anchor + Translation2d(anchor.distance(poses[i - 1].translation()) / 3.0,
                                                       poses[i].rotation() + Rotation2d.fromDegrees(180)))
            # Anchor
            bezierPoints.append(anchor)
            # Next control
            bezierPoints.append(
                anchor + Translation2d(anchor.distance(poses[i + 1].translation()) / 3.0, poses[i].rotation()))

        # Last pose
        bezierPoints.append(poses[len(poses) - 1].translation() + Translation2d(
            poses[len(poses) - 1].translation().distance(poses[len(poses) - 2].translation()) / 3.0,
            poses[len(poses) - 1].rotation() + Rotation2d.fromDegrees(180)))
        bezierPoints.append(poses[len(poses) - 1].translation())

        return bezierPoints

    def getAllPathPoints(self) -> List[PathPoint]:
        return self._allPoints

    def numPoints(self) -> int:
        return len(self._allPoints)

    def getPoint(self, index: int) -> PathPoint:
        return self._allPoints[index]

    def getGlobalConstraints(self) -> PathConstraints:
        return self._globalConstraints

    def getGoalEndState(self) -> GoalEndState:
        return self._goalEndState

    def getEventMarkers(self) -> List[EventMarker]:
        return self._eventMarkers

    def isReversed(self) -> bool:
        return self._reversed

    def getStartingDifferentialPose(self) -> Pose2d:
        startPos = self.getPoint(0).position
        heading = (self.getPoint(1).position - self.getPoint(0).position).angle()

        if self._reversed:
            heading = Rotation2d.fromDegrees(inputModulus(heading.degrees() + 180, -180, 180))

        return Pose2d(startPos, heading)

    def getPreviewStartingHolonomicPose(self) -> Pose2d:
        heading = Rotation2d() if self._previewStartingRotation is None else self._previewStartingRotation
        return Pose2d(self.getPoint(0).position, heading)

    def replan(self, starting_pose: Pose2d, current_speeds: ChassisSpeeds) -> PathPlannerPath:
        currentFieldRelativeSpeeds = ChassisSpeeds.fromFieldRelativeSpeeds(current_speeds.vx, current_speeds.vy,
                                                                           current_speeds.omega,
                                                                           -starting_pose.rotation())

        robotNextControl = None
        linearVel = math.hypot(currentFieldRelativeSpeeds.vx, currentFieldRelativeSpeeds.vy)
        if linearVel > 0.1:
            stoppingDistance = (linearVel ** 2) / (2 * self._globalConstraints.maxAccelerationMpsSq)

            heading = Rotation2d(currentFieldRelativeSpeeds.vx, currentFieldRelativeSpeeds.vy)
            robotNextControl = starting_pose.translation() + Translation2d(stoppingDistance, heading)

        closestPointIdx = 0
        comparePoint = robotNextControl if robotNextControl is not None else starting_pose.translation()
        closestDist = PathPlannerPath._positionDelta(comparePoint, self.getPoint(closestPointIdx).position)

        for i in range(1, self.numPoints()):
            d = PathPlannerPath._positionDelta(comparePoint, self.getPoint(i).position)

            if d < closestDist:
                closestPointIdx = i
                closestDist = d

        if closestPointIdx == self.numPoints() - 1:
            heading = (self.getPoint(self.numPoints() - 1).position - comparePoint).angle()

            if robotNextControl is None:
                robotNextControl = starting_pose.translation() + Translation2d(closestDist / 3.0, heading)

            endPrevControlHeading = (self.getPoint(self.numPoints() - 1).position - robotNextControl).angle()

            endPrevControl = self.getPoint(self.numPoints() - 1).position - Translation2d(closestDist / 3.0,
                                                                                          endPrevControlHeading)

            # Throw out rotation targets, event markers, and constraint zones since we are skipping all
            # of the path
            return PathPlannerPath(
                [starting_pose.translation(), robotNextControl, endPrevControl,
                 self.getPoint(self.numPoints() - 1).position],
                self._globalConstraints,
                self._goalEndState, [], [], [], self._reversed, self._previewStartingRotation)
        elif (closestPointIdx == 0 and robotNextControl is None) or (math.fabs(
                closestDist - starting_pose.translation().distance(
                    self.getPoint(0).position)) <= 0.25 and linearVel < 0.1):
            distToStart = starting_pose.translation().distance(self.getPoint(0).position)

            heading = (self.getPoint(0).position - starting_pose.translation()).angle()
            robotNextControl = starting_pose.translation() + Translation2d(distToStart / 3.0, heading)

            joinHeading = (self.getPoint(0).position - self.getPoint(1).position).angle()
            joinPrevControl = self.getPoint(0).position + Translation2d(distToStart / 2.0, joinHeading)

            if len(self._bezierPoints) == 0:
                # We don't have any bezier points to reference
                joinSegment = PathSegment(starting_pose.translation(), robotNextControl, joinPrevControl,
                                          self.getPoint(0).position, end_segment=False)
                replannedPoints = []
                replannedPoints.extend(joinSegment.segmentPoints)
                replannedPoints.extend(self._allPoints)

                return PathPlannerPath.fromPathPoints(replannedPoints, self._globalConstraints, self._goalEndState)
            else:
                # We can use the bezier points
                replannedBezier = [starting_pose.translation(), robotNextControl, joinPrevControl]
                replannedBezier.extend(self._bezierPoints)

                # Keep all rotations, markers, and zones and increment waypoint pos by 1
                return PathPlannerPath(
                    replannedBezier, self._globalConstraints, self._goalEndState,
                    [RotationTarget(t.waypointRelativePosition + 1, t.target, t.rotateFast) for t in
                     self._rotationTargets],
                    [ConstraintsZone(z.minWaypointPos + 1, z.maxWaypointPos + 1, z.constraints) for z in
                     self._constraintZones],
                    [EventMarker(m.waypointRelativePos + 1, m.command, m.minimumTriggerDistance) for m in
                     self._eventMarkers],
                    self._reversed,
                    self._previewStartingRotation
                )

        joinAnchorIdx = self.numPoints() - 1
        for i in range(closestPointIdx, self.numPoints()):
            if self.getPoint(i).distanceAlongPath >= self.getPoint(closestPointIdx).distanceAlongPath + closestDist:
                joinAnchorIdx = i
                break

        joinPrevControl = self.getPoint(closestPointIdx).position
        joinAnchor = self.getPoint(joinAnchorIdx).position

        if robotNextControl is None:
            robotToJoinDelta = starting_pose.translation().distance(joinAnchor)
            heading = (joinPrevControl - starting_pose.translation()).angle()
            robotNextControl = starting_pose.translation() + Translation2d(robotToJoinDelta / 3.0, heading)

        if joinAnchorIdx == self.numPoints() - 1:
            # Throw out rotation targets, event markers, and constraint zones since we are skipping all
            # of the path
            return PathPlannerPath(
                [starting_pose.translation(), robotNextControl, joinPrevControl, joinAnchor],
                self._globalConstraints, self._goalEndState,
                [], [], [], self._reversed, self._previewStartingRotation
            )

        if len(self._bezierPoints) == 0:
            # We don't have any bezier points to reference
            joinSegment = PathSegment(starting_pose.translation(), robotNextControl, joinPrevControl, joinAnchor,
                                      end_segment=False)
            replannedPoints = []
            replannedPoints.extend(joinSegment.segmentPoints)
            replannedPoints.extend(self._allPoints[joinAnchorIdx:])

            return PathPlannerPath.fromPathPoints(replannedPoints, self._globalConstraints, self._goalEndState)

        # We can reference bezier points
        nextWaypointIdx = math.ceil((joinAnchorIdx + 1) * RESOLUTION)
        bezierPointIdx = nextWaypointIdx * 3
        waypointDelta = joinAnchor.distance(self._bezierPoints[bezierPointIdx])

        joinHeading = (joinAnchor - joinPrevControl).angle()
        joinNextControl = joinAnchor + Translation2d(waypointDelta / 3.0, joinHeading)

        if bezierPointIdx == len(self._bezierPoints) - 1:
            nextWaypointHeading = (self._bezierPoints[bezierPointIdx - 1] - self._bezierPoints[bezierPointIdx]).angle()
        else:
            nextWaypointHeading = (self._bezierPoints[bezierPointIdx] - self._bezierPoints[bezierPointIdx + 1]).angle()

        nextWaypointPrevControl = self._bezierPoints[bezierPointIdx] + Translation2d(max(waypointDelta / 3.0, 0.15),
                                                                                     nextWaypointHeading)

        replannedBezier = [
            starting_pose.translation(),
            robotNextControl,
            joinPrevControl,
            joinAnchor,
            joinNextControl,
            nextWaypointPrevControl
        ]
        replannedBezier.extend(self._bezierPoints[bezierPointIdx:])

        segment1Length = 0
        lastSegment1Pos = starting_pose.translation()
        segment2Length = 0
        lastSegment2Pos = joinAnchor

        for t in decimal_range(RESOLUTION, 1.0, RESOLUTION):
            p1 = cubicLerp(starting_pose.translation(), robotNextControl, joinPrevControl, joinAnchor, t)
            p2 = cubicLerp(joinAnchor, joinNextControl, nextWaypointPrevControl, self._bezierPoints[bezierPointIdx], t)

            segment1Length += PathPlannerPath._positionDelta(lastSegment1Pos, p1)
            segment2Length += PathPlannerPath._positionDelta(lastSegment2Pos, p2)

            lastSegment1Pos = p1
            lastSegment2Pos = p2

        segment1Pct = segment1Length / (segment1Length + segment2Length)

        mappedTargets = []
        mappedZones = []
        mappedMarkers = []

        for t in self._rotationTargets:
            if t.waypointRelativePosition >= nextWaypointIdx:
                mappedTargets.append(
                    RotationTarget(t.waypointRelativePosition - nextWaypointIdx + 2, t.target, t.rotateFast))
            elif t.waypointRelativePosition >= nextWaypointIdx - 1:
                pct = t.waypointRelativePosition - (nextWaypointIdx - 1)
                mappedTargets.append(RotationTarget(PathPlannerPath._mapPct(pct, segment1Pct), t.target, t.rotateFast))

        for z in self._constraintZones:
            minPos = 0
            maxPos = 0

            if z.minWaypointPos >= nextWaypointIdx:
                minPos = z.minWaypointPos - nextWaypointIdx + 2
            elif z.minWaypointPos >= nextWaypointIdx - 1:
                pct = z.minWaypointPos - (nextWaypointIdx - 1)
                minPos = PathPlannerPath._mapPct(pct, segment1Pct)

            if z.maxWaypointPos >= nextWaypointIdx:
                maxPos = z.maxWaypointPos - nextWaypointIdx + 2
            elif z.maxWaypointPos >= nextWaypointIdx - 1:
                pct = z.maxWaypointPos - (nextWaypointIdx - 1)
                maxPos = PathPlannerPath._mapPct(pct, segment1Pct)

            if maxPos > 0:
                mappedZones.append(ConstraintsZone(minPos, maxPos, z.constraints))

        for m in self._eventMarkers:
            if m.waypointRelativePos >= nextWaypointIdx:
                mappedMarkers.append(
                    EventMarker(m.waypointRelativePos - nextWaypointIdx + 2, m.command, m.minimumTriggerDistance))
            elif m.waypointRelativePos >= nextWaypointIdx - 1:
                pct = m.waypointRelativePos - (nextWaypointIdx - 1)
                mappedMarkers.append(
                    EventMarker(PathPlannerPath._mapPct(pct, segment1Pct), m.command, m.minimumTriggerDistance))

        # Throw out everything before nextWaypointIdx - 1, map everything from nextWaypointIdx -
        # 1 to nextWaypointIdx on to the 2 joining segments (waypoint rel pos within old segment = %
        # along distance of both new segments)
        return PathPlannerPath(
            replannedBezier, self._globalConstraints, self._goalEndState,
            mappedTargets, mappedZones, mappedMarkers, self._reversed, self._previewStartingRotation
        )

    @staticmethod
    def _mapPct(pct: float, seg1_pct: float) -> float:
        if pct <= seg1_pct:
            # Map to segment 1
            mappedPct = pct / seg1_pct
        else:
            # Map to segment 2
            mappedPct = 1 + ((pct - seg1_pct) / (1.0 - seg1_pct))

        # Round to nearest resolution step
        return round(mappedPct * (1.0 / RESOLUTION)) / (1.0 / RESOLUTION)

    @staticmethod
    def _positionDelta(a: Translation2d, b: Translation2d) -> float:
        delta = a - b
        return math.fabs(delta.X()) + math.fabs(delta.Y())

    @staticmethod
    def _fromJson(path_json: dict) -> PathPlannerPath:
        bezierPoints = PathPlannerPath._bezierPointsFromWaypointsJson(path_json['waypoints'])
        globalConstraints = PathConstraints.fromJson(path_json['globalConstraints'])
        goalEndState = GoalEndState.fromJson(path_json['goalEndState'])
        isReversed = bool(path_json['reversed'])
        rotationTargets = [RotationTarget.fromJson(rotJson) for rotJson in path_json['rotationTargets']]
        constraintZones = [ConstraintsZone.fromJson(zoneJson) for zoneJson in path_json['constraintZones']]
        eventMarkers = [EventMarker.fromJson(markerJson) for markerJson in path_json['eventMarkers']]
        previewStartingRotation = Rotation2d()
        if path_json['previewStartingState'] is not None:
            previewStartingRotation = Rotation2d.fromDegrees(float(path_json['previewStartingState']['rotation']))

        return PathPlannerPath(bezierPoints, globalConstraints, goalEndState, rotationTargets, constraintZones,
                               eventMarkers, isReversed, previewStartingRotation)

    @staticmethod
    def _bezierPointsFromWaypointsJson(waypoints_json) -> List[Translation2d]:
        bezierPoints = []

        # First point
        firstPointJson = waypoints_json[0]
        bezierPoints.append(PathPlannerPath._pointFromJson(firstPointJson['anchor']))
        bezierPoints.append(PathPlannerPath._pointFromJson(firstPointJson['nextControl']))

        # Mid points
        for i in range(1, len(waypoints_json) - 1):
            point = waypoints_json[i]
            bezierPoints.append(PathPlannerPath._pointFromJson(point['prevControl']))
            bezierPoints.append(PathPlannerPath._pointFromJson(point['anchor']))
            bezierPoints.append(PathPlannerPath._pointFromJson(point['nextControl']))

        # Last point
        lastPointJson = waypoints_json[len(waypoints_json) - 1]
        bezierPoints.append(PathPlannerPath._pointFromJson(lastPointJson['prevControl']))
        bezierPoints.append(PathPlannerPath._pointFromJson(lastPointJson['anchor']))

        return bezierPoints

    @staticmethod
    def _pointFromJson(point_json: dict) -> Translation2d:
        x = float(point_json['x'])
        y = float(point_json['y'])

        return Translation2d(x, y)

    @staticmethod
    def _createPath(bezier_points: List[Translation2d], holonomic_rotations: List[RotationTarget],
                    constraint_zones: List[ConstraintsZone]) -> List[PathPoint]:
        if len(bezier_points) < 4:
            raise ValueError('Not enough bezier points')

        points = []

        numSegments = int((len(bezier_points) - 1) / 3)
        for s in range(numSegments):
            iOffset = s * 3
            p1 = bezier_points[iOffset]
            p2 = bezier_points[iOffset + 1]
            p3 = bezier_points[iOffset + 2]
            p4 = bezier_points[iOffset + 3]

            segmentIdx = s
            segmentRotations = [t.forSegmentIndex(segmentIdx) for t in holonomic_rotations if
                                segmentIdx <= t.waypointRelativePosition <= segmentIdx + 1]
            segmentZones = [z.forSegmentIndex(segmentIdx) for z in constraint_zones if
                            z.overlapsRange(segmentIdx, segmentIdx + 1)]

            segment = PathSegment(p1, p2, p3, p4, segmentRotations, segmentZones, s == numSegments - 1)
            points.extend(segment.segmentPoints)

        return points

    def _precalcValues(self) -> None:
        if self.numPoints() > 0:
            for i in range(self.numPoints()):
                point = self.getPoint(i)
                if point.constraints is None:
                    point.constraints = self._globalConstraints
                point.curveRadius = self._getCurveRadiusAtPoint(i)

                if math.isfinite(point.curveRadius):
                    point.maxV = min(math.sqrt(point.constraints.maxAccelerationMpsSq * math.fabs(point.curveRadius)),
                                     point.constraints.maxVelocityMps)
                else:
                    point.maxV = point.constraints.maxVelocityMps

                if i != 0:
                    point.distanceAlongPath = self.getPoint(i - 1).distanceAlongPath + (
                        self.getPoint(i - 1).position.distance(point.position))

            for m in self._eventMarkers:
                pointIndex = int(m.waypointRelativePos / RESOLUTION)
                m.markerPos = self.getPoint(pointIndex).position

            self.getPoint(self.numPoints() - 1).rotationTarget = RotationTarget(-1, self._goalEndState.rotation,
                                                                                self._goalEndState.rotateFast)
            self.getPoint(self.numPoints() - 1).maxV = self._goalEndState.velocity

    def _getCurveRadiusAtPoint(self, index: int) -> float:
        if self.numPoints() < 3:
            return float('inf')

        if index == 0:
            return calculateRadius(
                self.getPoint(index).position,
                self.getPoint(index + 1).position,
                self.getPoint(index + 2).position)
        elif index == self.numPoints() - 1:
            return calculateRadius(
                self.getPoint(index - 2).position,
                self.getPoint(index - 1).position,
                self.getPoint(index).position)
        else:
            return calculateRadius(
                self.getPoint(index - 1).position,
                self.getPoint(index).position,
                self.getPoint(index + 1).position)
