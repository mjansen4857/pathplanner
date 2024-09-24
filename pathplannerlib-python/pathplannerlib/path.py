from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Final, List, Union
from wpimath.geometry import Rotation2d, Translation2d, Pose2d
from wpimath.kinematics import ChassisSpeeds
import wpimath.units as units
from wpimath import inputModulus
from commands2 import Command
from .geometry_util import cubicLerp, calculateRadius, flipFieldPos, flipFieldRotation, floatLerp
from .trajectory import PathPlannerTrajectory, PathPlannerTrajectoryState
from .config import RobotConfig
from .events import ScheduleCommandEvent
from wpilib import getDeployDirectory
from hal import report, tResourceType
import os
import json

targetIncrement: Final[float] = 0.05
targetSpacing: Final[float] = 0.2


@dataclass(frozen=True)
class PathConstraints:
    """
    Kinematic path following constraints

    Args:
        maxVelocityMps (float): Max linear velocity (M/S)
        maxAccelerationMpsSq (float): Max linear acceleration (M/S^2)
        maxAngularVelocityRps (float): Max angular velocity (Rad/S)
        maxAngularAccelerationRpsSq (float): Max angular acceleration (Rad/S^2)
    """
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
    """
    Describes the goal end state of the robot when finishing a path

    Args:
        velocity (float): The goal end velocity (M/S)
        rotation (Rotation2d): The goal rotation
    """
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
class IdealStartingState:
    """
    Describes the ideal starting state of the robot when finishing a path

    Args:
        velocity (float): The ideal starting velocity (M/S)
        rotation (Rotation2d): The ideal starting rotation
    """
    velocity: float
    rotation: Rotation2d

    @staticmethod
    def fromJson(json_dict: dict) -> IdealStartingState:
        vel = float(json_dict['velocity'])
        deg = float(json_dict['rotation'])

        return IdealStartingState(vel, Rotation2d.fromDegrees(deg))

    def __eq__(self, other):
        return (isinstance(other, IdealStartingState)
                and other.velocity == self.velocity
                and other.rotation == self.rotation)


@dataclass(frozen=True)
class ConstraintsZone:
    """
    A zone on a path with different kinematic constraints

    Args:
        minWaypointPos (float): Starting position of the zone
        maxWaypointPos (float): End position of the zone
        constraints (PathConstraints): PathConstraints to apply within the zone
    """
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
        """
        Get if a given waypoint relative position is within this zone

        :param t: Waypoint relative position
        :return: True if given position is within this zone
        """
        return self.minWaypointPos <= t <= self.maxWaypointPos

    def overlapsRange(self, min_pos: float, max_pos: float) -> bool:
        """
        Get if this zone overlaps a given range

        :param min_pos: The minimum waypoint relative position of the range
        :param max_pos: The maximum waypoint relative position of the range
        :return: True if any part of this zone is within the given range
        """
        return max(min_pos, self.minWaypointPos) <= min(max_pos, self.maxWaypointPos)

    def forSegmentIndex(self, segment_index: int) -> ConstraintsZone:
        """
        Transform the positions of this zone for a given segment number.

        For example, a zone from [1.5, 2.0] for the segment 1 will have the positions [0.5, 1.0]

        :param segment_index: The segment index to transform positions for
        :return: The transformed zone
        """
        return ConstraintsZone(self.minWaypointPos - segment_index, self.maxWaypointPos - segment_index,
                               self.constraints)

    def __eq__(self, other):
        return (isinstance(other, ConstraintsZone)
                and other.minWaypointPos == self.minWaypointPos
                and other.maxWaypointPos == self.maxWaypointPos
                and other.constraints == self.constraints)


@dataclass(frozen=True)
class RotationTarget:
    """
    A target holonomic rotation at a position along a path

    Args:
        waypointRelativePosition (float): Waypoint relative position of this target
        target (Rotation2d): Target rotation
    """
    waypointRelativePosition: float
    target: Rotation2d

    @staticmethod
    def fromJson(json_dict: dict) -> RotationTarget:
        pos = float(json_dict['waypointRelativePos'])
        deg = float(json_dict['rotationDegrees'])

        return RotationTarget(pos, Rotation2d.fromDegrees(deg))

    def forSegmentIndex(self, segment_index: int) -> RotationTarget:
        """
        Transform the position of this target for a given segment number.

        For example, a target with position 1.5 for the segment 1 will have the position 0.5

        :param segment_index: The segment index to transform position for
        :return: The transformed target
        """
        return RotationTarget(self.waypointRelativePosition - segment_index, self.target)

    def __eq__(self, other):
        return (isinstance(other, RotationTarget)
                and other.waypointRelativePosition == self.waypointRelativePosition
                and other.target == self.target)


@dataclass
class EventMarker:
    """
    Position along the path that will trigger a command when reached

    Args:
        waypointRelativePos (float): The waypoint relative position of the marker
        command (Command): The command that should be triggered at this marker
    """
    waypointRelativePos: float
    command: Command

    @staticmethod
    def fromJson(json_dict: dict) -> EventMarker:
        pos = float(json_dict['waypointRelativePos'])
        from .auto import CommandUtil
        command = CommandUtil.commandFromJson(json_dict['command'], False)
        return EventMarker(pos, command)

    def __eq__(self, other):
        return (isinstance(other, EventMarker)
                and other.waypointRelativePos == self.waypointRelativePos
                and other.command == self.command)


@dataclass
class PathPoint:
    """
    A point along a pathplanner path

    Args:
        position (Translation2d): Position of the point
        rotationTarget (RotationTarget): Rotation target at this point
        constraints (PathConstraints): The constraints at this point
    """
    position: Translation2d
    rotationTarget: Union[RotationTarget, None] = None
    constraints: Union[PathConstraints, None] = None
    distanceAlongPath: float = 0.0
    maxV: float = float('inf')
    waypointRelativePos: float = 0.0

    def flip(self) -> PathPoint:
        flipped = PathPoint(flipFieldPos(self.position))
        flipped.distanceAlongPath = self.distanceAlongPath
        flipped.maxV = self.maxV
        if self.rotationTarget is not None:
            flipped.rotationTarget = RotationTarget(self.rotationTarget.waypointRelativePosition,
                                                    flipFieldRotation(self.rotationTarget.target))
        flipped.constraints = self.constraints
        flipped.waypointRelativePos = self.waypointRelativePos
        return flipped

    def __eq__(self, other):
        return (isinstance(other, PathPoint)
                and other.position == self.position
                and other.holonomicRotation == self.rotationTarget
                and other.constraints == self.constraints
                and other.distanceAlongPath == self.distanceAlongPath
                and other.maxV == self.maxV)


class PathPlannerPath:
    _bezierPoints: List[Translation2d]
    _rotationTargets: List[RotationTarget]
    _constraintZones: List[ConstraintsZone]
    _eventMarkers: List[EventMarker]
    _globalConstraints: PathConstraints
    _goalEndState: GoalEndState
    _idealStartingState: IdealStartingState
    _allPoints: List[PathPoint]
    _reversed: bool

    _isChoreoPath: bool = False
    _idealTrajectory: Union[PathPlannerTrajectory, None] = None

    _instances: int = 0

    _pathCache: dict[str, PathPlannerPath] = {}
    _choreoPathCache: dict[str, PathPlannerPath] = {}

    preventFlipping: bool = False

    def __init__(self, bezier_points: List[Translation2d], constraints: PathConstraints,
                 ideal_starting_state: Union[IdealStartingState, None], goal_end_state: GoalEndState,
                 holonomic_rotations: List[RotationTarget] = None, constraint_zones: List[ConstraintsZone] = None,
                 event_markers: List[EventMarker] = None, is_reversed: bool = False):
        """
        Create a new path planner path

        :param bezier_points: List of points representing the cubic Bezier curve of the path
        :param constraints: The global constraints of the path
        :param ideal_starting_state: The ideal starting state of the path. Can be None if unknown
        :param goal_end_state: The goal end state of the path
        :param holonomic_rotations: List of rotation targets along the path
        :param constraint_zones: List of constraint zones along the path
        :param event_markers: List of event markers along the path
        :param is_reversed: Should the robot follow the path reversed (differential drive only)
        """
        self._bezierPoints = bezier_points
        if holonomic_rotations is None:
            self._rotationTargets = []
        else:
            self._rotationTargets = holonomic_rotations
            self._rotationTargets.sort(key=lambda x: x.waypointRelativePosition)
        if constraint_zones is None:
            self._constraintZones = []
        else:
            self._constraintZones = constraint_zones
        if event_markers is None:
            self._eventMarkers = []
        else:
            self._eventMarkers = event_markers
            self._eventMarkers.sort(key=lambda x: x.waypointRelativePosition)
        self._globalConstraints = constraints
        self._idealStartingState = ideal_starting_state
        self._goalEndState = goal_end_state
        self._reversed = is_reversed
        if len(bezier_points) >= 4 and (len(bezier_points) - 1) % 3 == 0:
            self._allPoints = self._createPath()
            self._precalcValues()

        PathPlannerPath._instances += 1
        report(tResourceType.kResourceType_PathPlannerPath.value, PathPlannerPath._instances)

    @staticmethod
    def fromPathPoints(path_points: List[PathPoint], constraints: PathConstraints,
                       goal_end_state: GoalEndState) -> PathPlannerPath:
        """
        Create a path with pre-generated points. This should already be a smooth path.

        :param path_points: Path points along the smooth curve of the path
        :param constraints: The global constraints of the path
        :param goal_end_state: The goal end state of the path
        :return: A PathPlannerPath following the given pathpoints
        """
        path = PathPlannerPath([], constraints, None, goal_end_state)
        path._allPoints = path_points
        path._precalcValues()

        return path

    @staticmethod
    def fromPathFile(path_name: str) -> PathPlannerPath:
        """
        Load a path from a path file in storage

        :param path_name: The name of the path to load
        :return: PathPlannerPath created from the given file name
        """
        if path_name in PathPlannerPath._pathCache:
            return PathPlannerPath._pathCache[path_name]

        filePath = os.path.join(getDeployDirectory(), 'pathplanner', 'paths', path_name + '.path')

        with open(filePath, 'r') as f:
            pathJson = json.loads(f.read())
            path = PathPlannerPath._fromJson(pathJson)
            PathPlannerPath._pathCache[path_name] = path
            return path

    @staticmethod
    def fromChoreoTrajectory(trajectory_name: str) -> PathPlannerPath:
        """
        Load a Choreo trajectory as a PathPlannerPath

        :param trajectory_name: The name of the Choreo trajectory to load. This should be just the name of the trajectory. The trajectories must be located in the "deploy/choreo" directory.
        :return: PathPlannerPath created from the given Choreo trajectory file
        """
        if trajectory_name in PathPlannerPath._choreoPathCache:
            return PathPlannerPath._choreoPathCache[trajectory_name]

        filePath = os.path.join(getDeployDirectory(), 'choreo', trajectory_name + '.traj')

        with open(filePath, 'r') as f:
            trajJson = json.loads(f.read())

            trajStates = []
            for s in trajJson['samples']:
                state = PathPlannerTrajectoryState()

                time = float(s['timestamp'])
                xPos = float(s['x'])
                yPos = float(s['y'])
                rotationRad = float(s['heading'])
                xVel = float(s['velocityX'])
                yVel = float(s['velocityY'])
                angularVelRps = float(s['angularVelocity'])

                state.timeSeconds = time
                state.linearVelocity = math.hypot(xVel, yVel)
                state.pose = Pose2d(xPos, yPos, rotationRad)
                state.fieldSpeeds = ChassisSpeeds(xVel, yVel, angularVelRps)

                trajStates.append(state)

            path = PathPlannerPath([], PathConstraints(
                float('inf'),
                float('inf'),
                float('inf'),
                float('inf')
            ), None, GoalEndState(trajStates[-1].linearVelocity, trajStates[-1].pose.rotation()))

            pathPoints = [PathPoint(state.pose.translation()) for state in trajStates]

            path._allPoints = pathPoints
            path._isChoreoPath = True

            events = []
            if 'eventMarkers' in trajJson:
                from .auto import CommandUtil
                for m in trajJson['eventMarkers']:
                    timestamp = float(m['timestamp'])
                    cmd = CommandUtil.commandFromJson(m['command'], False)

                    eventMarker = EventMarker(timestamp, cmd)

                    path._eventMarkers.append(eventMarker)
                    events.append(ScheduleCommandEvent(timestamp, cmd))

            events.sort(key=lambda a: a.getTimestamp())

            path._idealTrajectory = PathPlannerTrajectory(None, None, None, None, states=trajStates,
                                                          events=events)

            PathPlannerPath._choreoPathCache[trajectory_name] = path

            return path

    @staticmethod
    def clearPathCache():
        """
        Clear the cache of previously loaded paths.
        :return:
        """
        PathPlannerPath._pathCache.clear()
        PathPlannerPath._choreoPathCache.clear()

    @staticmethod
    def bezierFromPoses(poses: List[Pose2d]) -> List[Translation2d]:
        """
        Create the bezier points necessary to create a path using a list of poses

        :param poses: List of poses. Each pose represents one waypoint.
        :return: Bezier points
        """
        if len(poses) < 2:
            raise ValueError('Not enough poses')

        # First pose
        bezierPoints = [poses[0].translation(), poses[0].translation() + Translation2d(
            poses[0].translation().distance(poses[1].translation()) / 3.0,
            poses[0].rotation())]

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
        """
        Get all the path points in this path

        :return: Path points in the path
        """
        return self._allPoints

    def numPoints(self) -> int:
        """
        Get the number of points in this path

        :return: Number of points in the path
        """
        return len(self._allPoints)

    def getPoint(self, index: int) -> PathPoint:
        """
        Get a specific point along this path

        :param index: Index of the point to get
        :return: The point at the given index
        """
        return self._allPoints[index]

    def getConstraintsForPoint(self, idx: int) -> PathConstraints:
        """
        Get the constraints for a point along the path

        :param idx: Index of the point to get constraints for
        :return: The constraints that should apply to the point
        """
        if self.getPoint(idx).constraints is None:
            return self.getPoint(idx).constraints

        return self._globalConstraints

    def getGlobalConstraints(self) -> PathConstraints:
        """
        Get the global constraints for this path

        :return: Global constraints that apply to this path
        """
        return self._globalConstraints

    def getGoalEndState(self) -> GoalEndState:
        """
        Get the goal end state of this path

        :return: The goal end state
        """
        return self._goalEndState

    def getIdealStartingState(self) -> Union[IdealStartingState, None]:
        """
        Get the ideal starting state of this path

        :return: The ideal starting state
        """
        return self._idealStartingState

    def getEventMarkers(self) -> List[EventMarker]:
        """
        Get all the event markers for this path

        :return: The event markers for this path
        """
        return self._eventMarkers

    def isReversed(self) -> bool:
        """
        Should the path be followed reversed (differential drive only)

        :return: True if reversed
        """
        return self._reversed

    def getStartingDifferentialPose(self) -> Pose2d:
        """
        Get the differential pose for the start point of this path

        :return: Pose at the path's starting point
        """
        startPos = self.getPoint(0).position
        heading = self.getInitialHeading()

        if self._reversed:
            heading = Rotation2d.fromDegrees(inputModulus(heading.degrees() + 180, -180, 180))

        return Pose2d(startPos, heading)

    def isChoreoPath(self) -> bool:
        """
        Check if this path is loaded from a Choreo trajectory

        :return: True if this path is from choreo, false otherwise
        """
        return self._isChoreoPath

    def generateTrajectory(self, starting_speeds: ChassisSpeeds, starting_rotation: Rotation2d,
                           config: RobotConfig) -> PathPlannerTrajectory:
        """
        Generate a trajectory for this path.

        :param starting_speeds: The robot-relative starting speeds.
        :param starting_rotation: The starting rotation of the robot.
        :param config: The robot configuration
        :return: The generated trajectory.
        """
        if self._isChoreoPath:
            return self._idealTrajectory
        else:
            return PathPlannerTrajectory(self, starting_speeds, starting_rotation, config)

    def flipPath(self) -> PathPlannerPath:
        """
        Flip a path to the other side of the field, maintaining a global blue alliance origin
        :return: The flipped path
        """
        flippedTraj = None
        if self._idealTrajectory is not None:
            # Flip the ideal trajectory
            flippedTraj = self._idealTrajectory.flip()

        newBezier = [flipFieldPos(pos) for pos in self._bezierPoints]

        newRotTargets = [RotationTarget(t.waypointRelativePosition, flipFieldRotation(t.target)) for t in
                         self._rotationTargets]

        newPoints = [p.flip() for p in self._allPoints]

        path = PathPlannerPath.fromPathPoints(newPoints, self._globalConstraints,
                                              GoalEndState(self._goalEndState.velocity,
                                                           flipFieldRotation(self._goalEndState.rotation)))
        path._bezierPoints = newBezier
        path._rotationTargets = newRotTargets
        path._constraintZones = self._constraintZones
        path._eventMarkers = self._eventMarkers
        if self._idealStartingState is not None:
            path._idealStartingState = IdealStartingState(self._idealStartingState.velocity,
                                                          flipFieldRotation(self._idealStartingState.rotation))
        path._reversed = self._reversed
        path._isChoreoPath = self._isChoreoPath
        path._idealTrajectory = flippedTraj
        path.preventFlipping = self.preventFlipping

        return path

    def getPathPoses(self) -> List[Pose2d]:
        """
        Get a list of poses representing every point in this path.
        This can be used to display a path on a field 2d widget, for example.

        :return: List of poses for each point in this path
        """
        return [Pose2d(p.position, Rotation2d()) for p in self._allPoints]

    def getInitialHeading(self) -> Rotation2d:
        """
        Get the initial heading, or direction of travel, at the start of the path.

        :return: Initial heading
        """
        return (self.getPoint(1).position - self.getPoint(0).position).angle()

    def getIdealTrajectory(self, robotConfig: RobotConfig) -> Union[PathPlannerTrajectory, None]:
        """
        If possible, get the ideal trajectory for this path. This trajectory can be used if the robot
        is currently near the start of the path and at the ideal starting state. If there is no ideal
        starting state, there can be no ideal trajectory.

        :param robotConfig: The config to generate the ideal trajectory with if it has not already been generated
        :return: The ideal trajectory if it exists, None otherwise
        """
        if self._idealTrajectory is None and self._idealStartingState is not None:
            # The ideal starting state is known, generate the ideal trajectory
            heading = self.getInitialHeading()
            fieldSpeeds = Translation2d(self._idealStartingState.velocity, heading)
            startingSpeeds = ChassisSpeeds.fromFieldRelativeSpeeds(fieldSpeeds.x, fieldSpeeds.y, 0.0, heading)
            self._idealTrajectory = self.generateTrajectory(startingSpeeds, self._idealStartingState.rotation,
                                                            robotConfig)

        return self._idealTrajectory

    def _constraintsForWaypointPos(self, pos: float) -> PathConstraints:
        for z in self._constraintZones:
            if z.minWaypointPos <= pos <= z.maxWaypointPos:
                return z.constraints
        return self._globalConstraints

    def _samplePath(self, waypointRelativePos: float) -> Translation2d:
        s = min(int(waypointRelativePos), int((len(self._bezierPoints) - 1) / 3) - 1)
        iOffset = s * 3
        t = waypointRelativePos - s

        p1 = self._bezierPoints[iOffset]
        p2 = self._bezierPoints[iOffset + 1]
        p3 = self._bezierPoints[iOffset + 2]
        p4 = self._bezierPoints[iOffset + 3]
        return cubicLerp(p1, p2, p3, p4, t)

    @staticmethod
    def _fromJson(path_json: dict) -> PathPlannerPath:
        bezierPoints = PathPlannerPath._bezierPointsFromWaypointsJson(path_json['waypoints'])
        globalConstraints = PathConstraints.fromJson(path_json['globalConstraints'])
        goalEndState = GoalEndState.fromJson(path_json['goalEndState'])
        idealStartingState = IdealStartingState.fromJson(path_json['idealStartingState'])
        isReversed = bool(path_json['reversed'])
        rotationTargets = [RotationTarget.fromJson(rotJson) for rotJson in path_json['rotationTargets']]
        constraintZones = [ConstraintsZone.fromJson(zoneJson) for zoneJson in path_json['constraintZones']]
        eventMarkers = [EventMarker.fromJson(markerJson) for markerJson in path_json['eventMarkers']]

        return PathPlannerPath(bezierPoints, globalConstraints, idealStartingState, goalEndState, rotationTargets,
                               constraintZones,
                               eventMarkers, isReversed)

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

    def _createPath(self) -> List[PathPoint]:
        if len(self._bezierPoints) < 4 or (len(self._bezierPoints) - 1) % 3 != 0:
            raise ValueError('Invalid number of bezier points')

        unaddedTargets = [r for r in self._rotationTargets]
        points = []
        numSegments = int((len(self._bezierPoints) - 1) / 3)

        # Add the first path point
        points.append(PathPoint(self._samplePath(0.0), None, self._constraintsForWaypointPos(0.0)))
        points[-1].waypointRelativePos = 0.0

        pos = targetIncrement
        while pos < numSegments:
            position = self._samplePath(pos)

            distance = points[-1].position.distance(position)
            if distance <= 0.01:
                pos = min(pos + targetIncrement, numSegments)

            prevWaypointPos = pos - targetIncrement

            delta = distance - targetSpacing
            if delta > targetSpacing * 0.25:
                # Points are too far apart, increment t by correct amount
                correctIncrement = (targetSpacing * targetIncrement) / distance
                pos = pos - targetIncrement + correctIncrement

                position = self._samplePath(pos)

                if points[-1].position.distance(position) - targetSpacing > targetSpacing * 0.25:
                    # Points are still too far apart.Probably because of weird control
                    # point placement.Just cut the correct increment in half and hope for the best
                    pos = pos - (correctIncrement * 0.5)
                    position = self._samplePath(pos)
            elif delta < -targetSpacing * 0.25:
                # Points are too close, increment waypoint relative pos by correct amount
                correctIncrement = (targetSpacing * targetIncrement) / distance
                pos = pos - targetIncrement + correctIncrement

                position = self._samplePath(pos)

                if points[-1].position.distance(position) - targetSpacing < -targetSpacing * 0.25:
                    # Points are still too close. Probably because of weird control
                    # point placement. Just cut the correct increment in half and hope for the best
                    pos = pos + (correctIncrement * 0.5)
                    position = self._samplePath(pos)

            # Add a rotation target to the previous point if it is closer to it than
            # the current point
            if len(unaddedTargets) > 0:
                if abs(unaddedTargets[0].waypointRelativePosition - prevWaypointPos) <= abs(
                        unaddedTargets[0].waypointRelativePosition - pos):
                    points[-1].rotationTarget = unaddedTargets.pop(0)

            points.append(PathPoint(position, None, self._constraintsForWaypointPos(pos)))
            points[-1].waypointRelativePos = pos
            pos = min(pos + targetIncrement, numSegments)

        # Keep trying to add the end point until its close enough to the prev point
        trueIncrement = numSegments - (pos - targetIncrement)
        pos = numSegments
        invalid = True
        while invalid:
            position = self._samplePath(pos)

            distance = points[-1].position.distance(position)
            if distance <= 0.01:
                invalid = False
                break

            prevPos = pos - trueIncrement

            delta = distance - targetSpacing
            if delta > targetSpacing * 0.25:
                # Points are too far apart, increment t by correct amount
                correctIncrement = (targetSpacing * targetIncrement) / distance
                pos = pos - targetIncrement + correctIncrement
                trueIncrement = correctIncrement

                position = self._samplePath(pos)

                if points[-1].position.distance(position) - targetSpacing > targetSpacing * 0.25:
                    # Points are still too far apart.Probably because of weird control
                    # point placement.Just cut the correct increment in half and hope for the best
                    pos = pos - (correctIncrement * 0.5)
                    trueIncrement = correctIncrement * 0.5
                    position = self._samplePath(pos)
                else:
                    invalid = False

            # Add a rotation target to the previous point if it is closer to it than
            # the current point
            if len(unaddedTargets) > 0:
                if abs(unaddedTargets[0].waypointRelativePosition - prevPos) <= abs(
                        unaddedTargets[0].waypointRelativePosition - pos):
                    points[-1].rotationTarget = unaddedTargets.pop(0)

            points.append(PathPoint(position, None, self._constraintsForWaypointPos(pos)))
            points[-1].waypointRelativePos = pos
            pos = numSegments

        for i in range(1, len(points) - 1):
            curveRadius = calculateRadius(points[i - 1].position, points[i].position, points[i + 1].position)

            if not math.isfinite(curveRadius):
                continue

            if abs(curveRadius) < 0.25:
                # Curve radius is too tight for default spacing, insert 4 more points
                before1WaypointPos = floatLerp(points[i - 1].waypointRelativePos, points[i].waypointRelativePos, 0.33)
                before2WaypointPos = floatLerp(points[i - 1].waypointRelativePos, points[i].waypointRelativePos, 0.67)
                after1WaypointPos = floatLerp(points[i].waypointRelativePos, points[i + 1].waypointRelativePos, 0.33)
                after2WaypointPos = floatLerp(points[i].waypointRelativePos, points[i + 1].waypointRelativePos, 0.67)

                before1 = PathPoint(self._samplePath(before1WaypointPos), None,
                                    self._constraintsForWaypointPos(before1WaypointPos))
                before1.waypointRelativePos = before1WaypointPos
                before2 = PathPoint(self._samplePath(before2WaypointPos), None,
                                    self._constraintsForWaypointPos(before2WaypointPos))
                before2.waypointRelativePos = before2WaypointPos
                after1 = PathPoint(self._samplePath(after1WaypointPos), None,
                                   self._constraintsForWaypointPos(after1WaypointPos))
                after1.waypointRelativePos = after1WaypointPos
                after2 = PathPoint(self._samplePath(after2WaypointPos), None,
                                   self._constraintsForWaypointPos(after2WaypointPos))
                after2.waypointRelativePos = after2WaypointPos

                points.insert(i, before2)
                points.insert(i, before1)
                points.insert(i + 3, after2)
                points.insert(i + 3, after1)
                i += 4
            elif abs(curveRadius) < 0.5:
                # Curve radius is too tight for default spacing, insert 2 more points
                beforeWaypointPos = floatLerp(points[i - 1].waypointRelativePos, points[i].waypointRelativePos, 0.5)
                afterWaypointPos = floatLerp(points[i].waypointRelativePos, points[i + 1].waypointRelativePos, 0.5)

                before = PathPoint(self._samplePath(beforeWaypointPos), None,
                                   self._constraintsForWaypointPos(beforeWaypointPos))
                before.waypointRelativePos = beforeWaypointPos
                after = PathPoint(self._samplePath(afterWaypointPos), None,
                                  self._constraintsForWaypointPos(afterWaypointPos))
                after.waypointRelativePos = afterWaypointPos

                points.insert(i, before)
                points.insert(i + 2, after)
                i += 2

        return points

    def _precalcValues(self) -> None:
        if self.numPoints() > 0:
            for i in range(self.numPoints()):
                point = self.getPoint(i)
                if point.constraints is None:
                    point.constraints = self._globalConstraints
                curveRadius = self._getCurveRadiusAtPoint(i)

                if math.isfinite(curveRadius):
                    point.maxV = min(math.sqrt(point.constraints.maxAccelerationMpsSq * math.fabs(curveRadius)),
                                     point.constraints.maxVelocityMps)
                else:
                    point.maxV = point.constraints.maxVelocityMps

                if i != 0:
                    point.distanceAlongPath = self.getPoint(i - 1).distanceAlongPath + (
                        self.getPoint(i - 1).position.distance(point.position))

            self.getPoint(self.numPoints() - 1).rotationTarget = RotationTarget(-1, self._goalEndState.rotation)
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
