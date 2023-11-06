from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Final, List
from wpimath.geometry import Rotation2d, Translation2d, Pose2d
import wpimath.units as units
from commands2 import Command
import commands2.cmd as cmd
from geometry_util import decimal_range, cubicLerp, calculateRadius

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

    @staticmethod
    def fromJson(json_dict: dict) -> GoalEndState:
        vel = float(json_dict['velocity'])
        deg = float(json_dict['rotation'])

        return GoalEndState(vel, Rotation2d.fromDegrees(deg))

    def __eq__(self, other):
        return (isinstance(other, GoalEndState)
                and other.velocity == self.velocity
                and other.rotation == self.rotation)


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

    @staticmethod
    def fromJson(json_dict: dict) -> RotationTarget:
        pos = float(json_dict['waypointRelativePos'])
        deg = float(json_dict['rotationDegrees'])
        return RotationTarget(pos, Rotation2d.fromDegrees(deg))

    def forSegmentIndex(self, segment_index: int) -> RotationTarget:
        return RotationTarget(self.waypointRelativePosition - segment_index, self.target)

    def __eq__(self, other):
        return (isinstance(other, RotationTarget)
                and other.waypointRelativePosition == self.waypointRelativePosition
                and other.target == self.target)


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
        # TODO: get command from json
        command = cmd.none()
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
    holonomicRotation: Rotation2d
    constraints: PathConstraints = None
    distanceAlongPath: float = 0.0
    curveRadius: float = 0.0
    maxV: float = float('inf')

    def __eq__(self, other):
        return (isinstance(other, PathPoint)
                and other.position == self.position
                and other.holonomicRotation == self.holonomicRotation
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
                    holonomicRotation = target_holonomic_rotations.pop(0).target

            currentZone = self._findConstraintsZone(constraint_zones, t)

            if currentZone is not None:
                self.segmentPoints.append(
                    PathPoint(cubicLerp(p1, p2, p3, p4, t), holonomicRotation, currentZone.constraints))
            else:
                self.segmentPoints.append(PathPoint(cubicLerp(p1, p2, p3, p4, t), holonomicRotation))

        if end_segment:
            holonomicRotation = target_holonomic_rotations.pop(0).target if len(
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
            # TODO

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
