from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Final, List, Union
from wpimath.geometry import Rotation2d, Translation2d, Pose2d
from wpimath.kinematics import ChassisSpeeds
import wpimath.units as units
from wpimath import inputModulus
from commands2 import Command

from .events import OneShotTriggerEvent, ScheduleCommandEvent, Event
from .util import cubicLerp, calculateRadius, floatLerp, FlippingUtil, translation2dFromJson, DriveFeedforwards
from .trajectory import PathPlannerTrajectory, PathPlannerTrajectoryState
from .config import RobotConfig
from wpilib import getDeployDirectory
from hal import report, tResourceType
import os
import json

targetIncrement: Final[float] = 0.05
targetSpacing: Final[float] = 0.2
autoControlDistanceFactor: Final[float] = 0.4


@dataclass(frozen=True)
class PathConstraints:
    """
    Kinematic path following constraints

    Args:
        maxVelocityMps (float): Max linear velocity (M/S)
        maxAccelerationMpsSq (float): Max linear acceleration (M/S^2)
        maxAngularVelocityRps (float): Max angular velocity (Rad/S)
        maxAngularAccelerationRpsSq (float): Max angular acceleration (Rad/S^2)
        nominalVoltage (float): Nominal battery voltage (Volts)
        unlimited (bool): Should the constraints be unlimited
    """
    maxVelocityMps: float
    maxAccelerationMpsSq: float
    maxAngularVelocityRps: float
    maxAngularAccelerationRpsSq: float
    nominalVoltage: float = 12.0
    unlimited: bool = False

    @staticmethod
    def fromJson(json_dict: dict) -> PathConstraints:
        maxVel = float(json_dict['maxVelocity'])
        maxAccel = float(json_dict['maxAcceleration'])
        maxAngularVel = float(json_dict['maxAngularVelocity'])
        maxAngularAccel = float(json_dict['maxAngularAcceleration'])
        nominalVoltage = float(json_dict['nominalVoltage'])
        unlimited = bool(json_dict['unlimited'])

        return PathConstraints(
            maxVel,
            maxAccel,
            units.degreesToRadians(maxAngularVel),
            units.degreesToRadians(maxAngularAccel),
            nominalVoltage,
            unlimited)

    @staticmethod
    def unlimitedConstraints(nominalVoltage: float) -> PathConstraints:
        return PathConstraints(
            float('inf'),
            float('inf'),
            float('inf'),
            float('inf'),
            nominalVoltage,
            True
        )

    def __eq__(self, other):
        return (isinstance(other, PathConstraints)
                and other.maxVelocityMps == self.maxVelocityMps
                and other.maxAccelerationMpsSq == self.maxAccelerationMpsSq
                and other.maxAngularVelocityRps == self.maxAngularVelocityRps
                and other.maxAngularAccelerationRpsSq == self.maxAngularAccelerationRpsSq
                and other.nominalVoltage == self.nominalVoltage
                and other.unlimited == self.unlimited)


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
    Describes the ideal starting state of the robot when starting a path

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

    def __eq__(self, other):
        return (isinstance(other, RotationTarget)
                and other.waypointRelativePosition == self.waypointRelativePosition
                and other.target == self.target)


@dataclass(frozen=True)
class PointTowardsZone:
    """
    A zone on a path that will force the robot to point towards a position on the field

    Args:
        name (str): The name of this zone. Used for point towards zone triggers
        targetPosition  (Translation2d): The target field position in meters
        minWaypointRelativePos (float): Starting position of the zone
        maxWaypointRelativePos (float): End position of the zone
        rotationOffset (Rotation2d): A rotation offset to add on top of the angle to the target position. For
            example, if you want the robot to point away from the target position, use a rotation offset of 180 degrees
    """
    name: str
    targetPosition: Translation2d
    minWaypointRelativePos: float
    maxWaypointRelativePos: float
    rotationOffset: Rotation2d = field(default_factory=Rotation2d)

    @staticmethod
    def fromJson(json_dict: dict) -> PointTowardsZone:
        name = str(json_dict['name'])
        targetPos = translation2dFromJson(json_dict['fieldPosition'])
        minPos = float(json_dict['minWaypointRelativePos'])
        maxPos = float(json_dict['maxWaypointRelativePos'])
        deg = float(json_dict['rotationOffset'])

        return PointTowardsZone(name, targetPos, minPos, maxPos, Rotation2d.fromDegrees(deg))

    def flip(self) -> PointTowardsZone:
        """
        Flip this point towards zone to the other side of the field, maintaining a blue alliance origin

        :return: The flipped zone
        """
        return PointTowardsZone(self.name, FlippingUtil.flipFieldPosition(self.targetPosition),
                                self.minWaypointRelativePos,
                                self.maxWaypointRelativePos, self.rotationOffset)


@dataclass(frozen=True)
class EventMarker:
    """
    Position along the path that will trigger a command when reached

    Args:
        triggerName (str): The name of the trigger this event marker will control
        waypointRelativePos (float): The waypoint relative position of the marker
        endWaypointRelativePos (float): The end waypoint relative position of the event's zone.
            A value of -1.0 indicates that this event is not zoned.
        command (Command): The command that should be triggered at this marker. Can be None
    """
    triggerName: str
    waypointRelativePos: float
    endWaypointRelativePos: float = -1.0
    command: Union[Command, None] = None

    @staticmethod
    def fromJson(json_dict: dict) -> EventMarker:
        name = str(json_dict['name'])
        pos = float(json_dict['waypointRelativePos'])
        endPos = -1.0
        if 'endWaypointRelativePos' in json_dict and json_dict['endWaypointRelativePos'] is not None:
            endPos = float(json_dict['endWaypointRelativePos'])

        command = None
        if json_dict['command'] is not None:
            from .auto import CommandUtil
            command = CommandUtil.commandFromJson(json_dict['command'], False, False)
        return EventMarker(name, pos, endPos, command)

    def __eq__(self, other):
        return (isinstance(other, EventMarker)
                and other.triggerName == self.triggerName
                and other.waypointRelativePos == self.waypointRelativePos
                and other.endWaypointRelativePos == self.endWaypointRelativePos
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
        flipped = PathPoint(FlippingUtil.flipFieldPosition(self.position))
        flipped.distanceAlongPath = self.distanceAlongPath
        flipped.maxV = self.maxV
        if self.rotationTarget is not None:
            flipped.rotationTarget = RotationTarget(self.rotationTarget.waypointRelativePosition,
                                                    FlippingUtil.flipFieldRotation(self.rotationTarget.target))
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


@dataclass(frozen=True)
class Waypoint:
    prevControl: Union[Translation2d, None]
    anchor: Translation2d
    nextControl: Union[Translation2d, None]

    def flip(self) -> Waypoint:
        """
        Flip this waypoint to the other side of the field, maintaining a blue alliance origin

        :return: The flipped waypoint
        """
        flippedPrevControl = None if self.prevControl is None else FlippingUtil.flipFieldPosition(self.prevControl)
        flippedAnchor = FlippingUtil.flipFieldPosition(self.anchor)
        flippedNextControl = None if self.nextControl is None else FlippingUtil.flipFieldPosition(self.nextControl)
        return Waypoint(flippedPrevControl, flippedAnchor, flippedNextControl)

    @staticmethod
    def autoControlPoints(anchor: Translation2d, heading: Rotation2d, prevAnchor: Union[Translation2d, None],
                          nextAnchor: Union[Translation2d, None]) -> Waypoint:
        """
        Create a waypoint with auto calculated control points based on the positions of adjacent waypoints.
        This is used internally, and you probably shouldn't use this.

        :param anchor: The anchor point of the waypoint to create
        :param heading: The heading of this waypoint
        :param prevAnchor: The position of the previous anchor point. This can be None for the start point
        :param nextAnchor: The position of the next anchor point. This can be None for the end point
        :return: Waypoint with auto calculated control points
        """
        prevControl = None
        nextControl = None

        if prevAnchor is not None:
            d = anchor.distance(prevAnchor) * autoControlDistanceFactor
            prevControl = anchor - Translation2d(d, heading)
        if nextAnchor is not None:
            d = anchor.distance(nextAnchor) * autoControlDistanceFactor
            nextControl = anchor + Translation2d(d, heading)

        return Waypoint(prevControl, anchor, nextControl)

    @staticmethod
    def fromJson(waypointJson: dict) -> Waypoint:
        """
        Create a waypoint from JSON

        :param waypointJson: JSON object representing a waypoint
        :return: The waypoint created from JSON
        """
        anchor = translation2dFromJson(waypointJson['anchor'])
        prevControl = None if waypointJson['prevControl'] is None else translation2dFromJson(
            waypointJson['prevControl'])
        nextControl = None if waypointJson['nextControl'] is None else translation2dFromJson(
            waypointJson['nextControl'])
        return Waypoint(prevControl, anchor, nextControl)


class PathPlannerPath:
    _waypoints: List[Waypoint]
    _rotationTargets: List[RotationTarget]
    _pointTowardsZones: List[PointTowardsZone]
    _constraintZones: List[ConstraintsZone]
    _eventMarkers: List[EventMarker]
    _globalConstraints: PathConstraints
    _goalEndState: GoalEndState
    _idealStartingState: Union[IdealStartingState, None]
    _allPoints: List[PathPoint]
    _reversed: bool

    _isChoreoPath: bool = False
    _idealTrajectory: Union[PathPlannerTrajectory, None] = None

    _instances: int = 0

    _pathCache: dict[str, PathPlannerPath] = {}
    _choreoPathCache: dict[str, PathPlannerPath] = {}

    preventFlipping: bool = False
    name: str = ''

    def __init__(self, waypoints: List[Waypoint], constraints: PathConstraints,
                 ideal_starting_state: Union[IdealStartingState, None], goal_end_state: GoalEndState,
                 holonomic_rotations: List[RotationTarget] = None, point_towards_zones: List[PointTowardsZone] = None,
                 constraint_zones: List[ConstraintsZone] = None, event_markers: List[EventMarker] = None,
                 is_reversed: bool = False):
        """
        Create a new path planner path

        :param waypoints: List of waypoints representing the path. For on-the-fly paths, you likely want to use
            waypointsFromPoses to create these.
        :param constraints: The global constraints of the path
        :param ideal_starting_state: The ideal starting state of the path. Can be None if unknown
        :param goal_end_state: The goal end state of the path
        :param holonomic_rotations: List of rotation targets along the path
        :param constraint_zones: List of constraint zones along the path
        :param event_markers: List of event markers along the path
        :param is_reversed: Should the robot follow the path reversed (differential drive only)
        """
        self._waypoints = waypoints
        if holonomic_rotations is None:
            self._rotationTargets = []
        else:
            self._rotationTargets = holonomic_rotations
            self._rotationTargets.sort(key=lambda x: x.waypointRelativePosition)
        if point_towards_zones is None:
            self._pointTowardsZones = []
        else:
            self._pointTowardsZones = point_towards_zones
        if constraint_zones is None:
            self._constraintZones = []
        else:
            self._constraintZones = constraint_zones
        if event_markers is None:
            self._eventMarkers = []
        else:
            self._eventMarkers = event_markers
            self._eventMarkers.sort(key=lambda x: x.waypointRelativePos)
        self._globalConstraints = constraints
        self._idealStartingState = ideal_starting_state
        self._goalEndState = goal_end_state
        self._reversed = is_reversed
        if len(waypoints) >= 2:
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

            version = str(pathJson['version'])
            versions = version.split('.')

            if versions[0] != '2025':
                raise RuntimeError("Incompatible file version for '" + path_name
                                   + ".path'. Actual: '" + version
                                   + "' Expected: '2025.X'")

            path = PathPlannerPath._fromJson(pathJson)
            PathPlannerPath._pathCache[path_name] = path
            return path

    @staticmethod
    def fromChoreoTrajectory(trajectory_name: str, splitIndex: int = None) -> PathPlannerPath:
        """
        Load a Choreo trajectory as a PathPlannerPath

        :param trajectory_name: The name of the Choreo trajectory to load. This should be just the name of the trajectory. The trajectories must be located in the "deploy/choreo" directory.
        :param splitIndex: The index of the split to use
        :return: PathPlannerPath created from the given Choreo trajectory file
        """
        if splitIndex is not None:
            cacheName = trajectory_name + '.' + str(splitIndex)

            if cacheName in PathPlannerPath._choreoPathCache:
                return PathPlannerPath._choreoPathCache[cacheName]

            # Path is not in the cache, load the main trajectory to load all splits
            PathPlannerPath._loadChoreoTrajectoryIntoCache(trajectory_name)

            return PathPlannerPath._choreoPathCache[cacheName]

        if trajectory_name in PathPlannerPath._choreoPathCache:
            return PathPlannerPath._choreoPathCache[trajectory_name]

        dotIdx = trajectory_name.rfind('.')
        splitIdx = -1
        if dotIdx != -1:
            splitStr = trajectory_name[dotIdx + 1:]
            splitIdx = int(splitStr) if splitStr.isdecimal() else -1

        if splitIdx != -1:
            # The traj name includes a split index
            PathPlannerPath._loadChoreoTrajectoryIntoCache(trajectory_name[:dotIdx])
        else:
            # The traj name does not include a split index
            PathPlannerPath._loadChoreoTrajectoryIntoCache(trajectory_name)

        return PathPlannerPath._choreoPathCache[trajectory_name]

    @staticmethod
    def _loadChoreoTrajectoryIntoCache(trajectory_name: str) -> None:
        filePath = os.path.join(getDeployDirectory(), 'choreo', trajectory_name + '.traj')

        with open(filePath, 'r') as f:
            fJson = json.loads(f.read())

            version = 0

            try:
                version = int(fJson['version'])
            except ValueError:
                # Assume version 0
                pass

            if version > 1:
                raise RuntimeError("Incompatible file version for '" + trajectory_name
                                   + ".traj'. Actual: '" + str(version)
                                   + "' Expected: <= 1")

            trajJson = fJson['trajectory']

            fullTrajStates = []
            for s in trajJson['samples']:
                state = PathPlannerTrajectoryState()

                time = float(s['t'])
                xPos = float(s['x'])
                yPos = float(s['y'])
                rotationRad = float(s['heading'])
                xVel = float(s['vx'])
                yVel = float(s['vy'])
                angularVelRps = float(s['omega'])

                fx = s['fx']
                fy = s['fy']
                forcesX = []
                forcesY = []
                for i in range(len(fx)):
                    forcesX.append(float(fx[i]))
                    forcesY.append(float(fy[i]))

                state.timeSeconds = time
                state.linearVelocity = math.hypot(xVel, yVel)
                state.pose = Pose2d(xPos, yPos, rotationRad)
                state.fieldSpeeds = ChassisSpeeds(xVel, yVel, angularVelRps)
                if abs(state.linearVelocity) > 1e-6:
                    state.heading = Rotation2d(state.fieldSpeeds.vx, state.fieldSpeeds.vy)

                # The module forces are field relative, rotate them to be robot relative
                for i in range(len(forcesX)):
                    rotated = Translation2d(forcesX[i], forcesY[i]).rotateBy(-state.pose.rotation())
                    forcesX[i] = rotated.x
                    forcesY[i] = rotated.y

                # All other feedforwards besides X and Y components will be zeros because they cannot be
                # calculated without RobotConfig
                state.feedforwards = DriveFeedforwards(
                    [0.0] * len(forcesX),
                    [0.0] * len(forcesX),
                    [0.0] * len(forcesX),
                    forcesX,
                    forcesY
                )

                fullTrajStates.append(state)

            fullEvents: List[Event] = []
            if 'events' in fJson:
                for markerJson in fJson['events']:
                    name = str(markerJson['name'])

                    fromJson = markerJson['from']
                    fromOffsetJson = fromJson['offset']
                    fromTargetTimestamp = float(fromJson['targetTimestamp'])
                    fromOffset = float(fromOffsetJson['val'])
                    fromTimestamp = fromTargetTimestamp + fromOffset

                    fullEvents.append(OneShotTriggerEvent(fromTimestamp, name))

                    if markerJson['event'] is not None:
                        from .auto import CommandUtil
                        eventCommand = CommandUtil.commandFromJson(markerJson['event'], True, False)
                        fullEvents.append(ScheduleCommandEvent(fromTimestamp, eventCommand))
            fullEvents.sort(key=lambda e: e.getTimestamp())

            # Add the full path to the cache
            fullPath = PathPlannerPath([], PathConstraints.unlimitedConstraints(12.0), None,
                                       GoalEndState(fullTrajStates[-1].linearVelocity,
                                                    fullTrajStates[-1].pose.rotation()))
            fullPath._idealStartingState = IdealStartingState(
                math.hypot(fullTrajStates[0].fieldSpeeds.vx, fullTrajStates[0].fieldSpeeds.vy),
                fullTrajStates[0].pose.rotation()
            )
            fullPathPoints = [PathPoint(state.pose.translation()) for state in fullTrajStates]
            fullPath._allPoints = fullPathPoints
            fullPath._isChoreoPath = True
            fullPath._idealTrajectory = PathPlannerTrajectory(None, None, None, None, states=fullTrajStates,
                                                              events=fullEvents)
            fullPath.name = trajectory_name
            PathPlannerPath._choreoPathCache[trajectory_name] = fullPath

            splitsJson = trajJson['splits']
            splits = [int(s) for s in splitsJson]
            if len(splits) == 0 or int(splits[0]) != 0:
                splits.insert(0, 0)

            for i in range(len(splits)):
                name = trajectory_name + '.' + str(i)
                states = []

                splitStartIdx = splits[i]

                splitEndIdx = len(fullTrajStates)
                if i < len(splits) - 1:
                    splitEndIdx = splits[i + 1]

                startTime = fullTrajStates[splitStartIdx].timeSeconds
                endTime = fullTrajStates[splitEndIdx - 1].timeSeconds
                for s in range(splitStartIdx, splitEndIdx):
                    states.append(fullTrajStates[s].copyWithTime(fullTrajStates[s].timeSeconds - startTime))

                events: List[Event] = []
                for originalEvent in fullEvents:
                    if startTime <= originalEvent.getTimestamp() < endTime:
                        events.append(originalEvent.copyWithTime(originalEvent.getTimestamp() - startTime))

                path = PathPlannerPath([], PathConstraints.unlimitedConstraints(12.0), None,
                                       GoalEndState(states[-1].linearVelocity, states[-1].pose.rotation()))
                path._idealStartingState = IdealStartingState(
                    math.hypot(states[0].fieldSpeeds.vx, states[0].fieldSpeeds.vy),
                    states[0].pose.rotation()
                )
                pathPoints = [PathPoint(state.pose.translation()) for state in states]
                path._allPoints = pathPoints
                path._isChoreoPath = True
                path._idealTrajectory = PathPlannerTrajectory(None, None, None, None, states=states,
                                                              events=events)
                path.name = name
                PathPlannerPath._choreoPathCache[name] = path

    @staticmethod
    def clearPathCache():
        """
        Clear the cache of previously loaded paths.
        :return:
        """
        PathPlannerPath._pathCache.clear()
        PathPlannerPath._choreoPathCache.clear()

    @staticmethod
    def waypointsFromPoses(poses: List[Pose2d]) -> List[Waypoint]:
        """
        Create the bezier waypoints necessary to create a path using a list of poses

        :param poses: List of poses. Each pose represents one waypoint.
        :return: Bézier curve waypoints
        """
        if len(poses) < 2:
            raise ValueError('Not enough poses')

        # First pose
        waypoints = [
            Waypoint.autoControlPoints(poses[0].translation(), poses[0].rotation(), None, poses[1].translation())]

        # Middle poses
        for i in range(1, len(poses) - 1):
            waypoints.append(Waypoint.autoControlPoints(
                poses[i].translation(),
                poses[i].rotation(),
                poses[i - 1].translation(),
                poses[i + 1].translation()
            ))

        # Last pose
        waypoints.append(Waypoint.autoControlPoints(
            poses[-1].translation(),
            poses[-1].rotation(),
            poses[-2].translation(),
            None
        ))

        return waypoints

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

    def getStartingHolonomicPose(self) -> Union[Pose2d, None]:
        """
        Get the holonomic pose for the start point of this path. If the path does not have an ideal
        starting state, this will return None.

        :return: The ideal starting pose if an ideal starting state is present, None otherwise
        """
        if self._idealStartingState is None:
            return None

        startPos = self.getPoint(0).position
        rotation = self._idealStartingState.rotation

        return Pose2d(startPos, rotation)

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

        flippedEndState = GoalEndState(self._goalEndState.velocity,
                                       FlippingUtil.flipFieldRotation(self._goalEndState.rotation))
        path = PathPlannerPath([], self._globalConstraints, None, flippedEndState)
        path._allPoints = [p.flip() for p in self._allPoints]
        path._bezierPoints = [w.flip() for w in self._waypoints]
        path._rotationTargets = [RotationTarget(t.waypointRelativePosition, FlippingUtil.flipFieldRotation(t.target))
                                 for t in self._rotationTargets]
        path._pointTowardsZones = [z.flip() for z in self._pointTowardsZones]
        path._constraintZones = self._constraintZones
        path._eventMarkers = self._eventMarkers
        if self._idealStartingState is not None:
            path._idealStartingState = IdealStartingState(self._idealStartingState.velocity,
                                                          FlippingUtil.flipFieldRotation(
                                                              self._idealStartingState.rotation))
        path._reversed = self._reversed
        path._isChoreoPath = self._isChoreoPath
        path._idealTrajectory = flippedTraj
        path.preventFlipping = self.preventFlipping
        path.name = self.name

        return path

    @staticmethod
    def _mirrorTranslation(translation: Translation2d) -> Translation2d:
        return Translation2d(translation.X(), FlippingUtil.fieldSizeY - translation.Y())

    def mirrorPath(self) -> PathPlannerPath:
        """
        Mirror a path to the other side of the current alliance. For example, if this path is on the
        right of the blue alliance side of the field, it will be mirrored to the left of the blue
        alliance side of the field.
        :return: The mirrored path
        """
        path = PathPlannerPath([], PathConstraints(0, 0, 0, 0), None, GoalEndState(0, Rotation2d()))
    
        mirroredTraj = None
        if self._idealTrajectory is not None:
            traj = self._idealTrajectory
            # Flip the ideal trajectory
            mirroredTraj = PathPlannerTrajectory(None, None, None, None, states=[
                PathPlannerTrajectoryState(
                    timeSeconds=s.timeSeconds,
                    linearVelocity=s.linearVelocity,
                    pose=Pose2d(self._mirrorTranslation(s.pose.translation()), -s.pose.rotation()),
                    fieldSpeeds=ChassisSpeeds(s.fieldSpeeds.vx, -s.fieldSpeeds.vy, -s.fieldSpeeds.omega),
                    feedforwards=DriveFeedforwards(
                        accelerationsMPS=[
                            s.feedforwards.accelerationsMPS[1], s.feedforwards.accelerationsMPS[0],
                            s.feedforwards.accelerationsMPS[3], s.feedforwards.accelerationsMPS[2]
                        ],
                        forcesNewtons=[
                            s.feedforwards.forcesNewtons[1], s.feedforwards.forcesNewtons[0],
                            s.feedforwards.forcesNewtons[3], s.feedforwards.forcesNewtons[2]
                        ],
                        torqueCurrentsAmps=[
                            s.feedforwards.torqueCurrentsAmps[1], s.feedforwards.torqueCurrentsAmps[0],
                            s.feedforwards.torqueCurrentsAmps[3], s.feedforwards.torqueCurrentsAmps[2]
                        ],
                        robotRelativeForcesXNewtons=[
                            s.feedforwards.robotRelativeForcesXNewtons[1], s.feedforwards.robotRelativeForcesXNewtons[0],
                            s.feedforwards.robotRelativeForcesXNewtons[3], s.feedforwards.robotRelativeForcesXNewtons[2]
                        ],
                        robotRelativeForcesYNewtons=[
                            s.feedforwards.robotRelativeForcesYNewtons[1], s.feedforwards.robotRelativeForcesYNewtons[0],
                            s.feedforwards.robotRelativeForcesYNewtons[3], s.feedforwards.robotRelativeForcesYNewtons[2]
                        ]
                    ) if len(s.feedforwards.accelerationsMPS) == 4 else
                    DriveFeedforwards(
                        accelerationsMPS=[
                            s.feedforwards.accelerationsMPS[1], s.feedforwards.accelerationsMPS[0]
                        ],
                        forcesNewtons=[
                            s.feedforwards.forcesNewtons[1], s.feedforwards.forcesNewtons[0]
                        ],
                        torqueCurrentsAmps=[
                            s.feedforwards.torqueCurrentsAmps[1], s.feedforwards.torqueCurrentsAmps[0]
                        ],
                        robotRelativeForcesXNewtons=[
                            s.feedforwards.robotRelativeForcesXNewtons[1], s.feedforwards.robotRelativeForcesXNewtons[0]
                        ],
                        robotRelativeForcesYNewtons=[
                            s.feedforwards.robotRelativeForcesYNewtons[1], s.feedforwards.robotRelativeForcesYNewtons[0]
                        ]
                    ) if len(s.feedforwards.accelerationsMPS) == 2 else s.feedforwards,
                    heading=-s.heading
                )
                for s in traj.getStates()
            ], events=traj.getEvents())
    
        path._waypoints = [
            Waypoint(
                prevControl=self._mirrorTranslation(w.prevControl) if w.prevControl is not None else None,
                anchor=self._mirrorTranslation(w.anchor),
                nextControl=self._mirrorTranslation(w.nextControl) if w.nextControl is not None else None
            ) for w in self._waypoints]
        path._rotationTargets = [RotationTarget(t.waypointRelativePosition, -t.target) for t in self._rotationTargets]
        path._pointTowardsZones = [PointTowardsZone(
            z.name,
            self._mirrorTranslation(z.targetPosition),
            z.minWaypointRelativePos,
            z.maxWaypointRelativePos,
            z.rotationOffset
        ) for z in self._pointTowardsZones]
        path._constraintZones = self._constraintZones
        path._eventMarkers = self._eventMarkers
        path._globalConstraints = self._globalConstraints
        if self._idealStartingState is not None:
            path._idealStartingState = IdealStartingState(self._idealStartingState.velocity, -self._idealStartingState.rotation)
        else:
            path._idealStartingState = None
        path._goalEndState = GoalEndState(self._goalEndState.velocity, -self._goalEndState.rotation)
    
        path._allPoints = [
            PathPoint(self._mirrorTranslation(p.position))
            for p in self._allPoints
        ]
        for i, p in enumerate(self._allPoints):
            new_point = path._allPoints[i]
            new_point.distanceAlongPath = p.distanceAlongPath
            new_point.maxV = p.maxV
            if p.rotationTarget is not None:
                new_point.rotationTarget = RotationTarget(
                    p.rotationTarget.waypointRelativePosition,
                    -p.rotationTarget.target
                )
            new_point.constraints = p.constraints
            new_point.waypointRelativePos = p.waypointRelativePos
        path._reversed = self._reversed
        path._isChoreoPath = self._isChoreoPath
        path._idealTrajectory = mirroredTraj
        path.preventFlipping = self.preventFlipping
        path.name = self.name
    
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

    def getWaypoints(self) -> List[Waypoint]:
        """
        Get the waypoints for this path

        :return: List of this path's waypoints
        """
        return self._waypoints

    def getRotationTargets(self) -> List[RotationTarget]:
        """
        Get the rotation targets for this path

        :return: List of this path's rotation targets
        """
        return self._rotationTargets

    def getPointTowardsZones(self) -> List[PointTowardsZone]:
        """
        Get the point towards zones for this path

        :return: List of this path's point towards zones
        """
        return self._pointTowardsZones

    def getConstraintZones(self) -> List[ConstraintsZone]:
        """
        Get the constraint zones for this path

        :return: List of this path's constraint zones
        """
        return self._constraintZones

    def _constraintsForWaypointPos(self, pos: float) -> PathConstraints:
        for z in self._constraintZones:
            if z.minWaypointPos <= pos <= z.maxWaypointPos:
                return z.constraints

        # Check if constraints should be unlimited
        if self._globalConstraints.unlimited:
            return PathConstraints.unlimitedConstraints(self._globalConstraints.nominalVoltage)

        return self._globalConstraints

    def _pointZoneForWaypointPos(self, pos: float) -> Union[PointTowardsZone, None]:
        for z in self._pointTowardsZones:
            if z.minWaypointRelativePos <= pos <= z.maxWaypointRelativePos:
                return z
        return None

    def _samplePath(self, waypointRelativePos: float) -> Translation2d:
        pos = min(max(waypointRelativePos, 0.0), len(self._waypoints) - 1)

        i = int(pos)
        if i == len(self._waypoints) - 1:
            i -= 1

        t = pos - i

        p1 = self._waypoints[i].anchor
        p2 = self._waypoints[i].nextControl
        p3 = self._waypoints[i + 1].prevControl
        p4 = self._waypoints[i + 1].anchor
        return cubicLerp(p1, p2, p3, p4, t)

    @staticmethod
    def _fromJson(path_json: dict) -> PathPlannerPath:
        waypoints = [Waypoint.fromJson(w) for w in path_json['waypoints']]
        globalConstraints = PathConstraints.fromJson(path_json['globalConstraints'])
        goalEndState = GoalEndState.fromJson(path_json['goalEndState'])
        idealStartingState = IdealStartingState.fromJson(path_json['idealStartingState'])
        isReversed = bool(path_json['reversed'])
        rotationTargets = [RotationTarget.fromJson(rotJson) for rotJson in path_json['rotationTargets']]
        pointTowardsZones = [PointTowardsZone.fromJson(zoneJson) for zoneJson in
                             path_json['pointTowardsZones']] if 'pointTowardsZones' in path_json else []
        constraintZones = [ConstraintsZone.fromJson(zoneJson) for zoneJson in path_json['constraintZones']]
        eventMarkers = [EventMarker.fromJson(markerJson) for markerJson in path_json['eventMarkers']]

        return PathPlannerPath(waypoints, globalConstraints, idealStartingState, goalEndState, rotationTargets,
                               pointTowardsZones, constraintZones, eventMarkers, isReversed)

    @staticmethod
    def _pointFromJson(point_json: dict) -> Translation2d:
        x = float(point_json['x'])
        y = float(point_json['y'])

        return Translation2d(x, y)

    def _createPath(self) -> List[PathPoint]:
        if len(self._waypoints) < 2:
            raise ValueError('A path must have at least 2 waypoints')

        unaddedTargets = [r for r in self._rotationTargets]
        points = []
        numSegments = len(self._waypoints) - 1

        # Add the first path point
        points.append(PathPoint(self._samplePath(0.0), None, self._constraintsForWaypointPos(0.0)))
        points[-1].waypointRelativePos = 0.0

        pos = targetIncrement
        while pos < numSegments:
            position = self._samplePath(pos)

            distance = points[-1].position.distance(position)
            if distance <= 0.01:
                pos = min(pos + targetIncrement, numSegments)
                continue

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

            # Add rotation targets
            target: Union[RotationTarget, None] = None
            prevPoint = points[-1]

            while len(unaddedTargets) > 0 and prevWaypointPos <= unaddedTargets[0].waypointRelativePosition <= pos:
                if abs(unaddedTargets[0].waypointRelativePosition - prevWaypointPos) < 0.001:
                    # Close enough to prev pos
                    prevPoint.rotationTarget = unaddedTargets.pop(0)
                elif abs(unaddedTargets[0].waypointRelativePosition - pos) < 0.001:
                    # Close enough to next pos
                    target = unaddedTargets.pop(0)
                else:
                    # We should insert a point at the exact position
                    t = unaddedTargets.pop(0)
                    points.append(PathPoint(self._samplePath(t.waypointRelativePosition), t,
                                            self._constraintsForWaypointPos(t.waypointRelativePosition)))
                    points[-1].waypointRelativePos = t.waypointRelativePosition

            points.append(PathPoint(position, target, self._constraintsForWaypointPos(pos)))
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
                if len(points) < 2:
                    points.append(PathPoint(position, None, self._constraintsForWaypointPos(pos)))
                    points[-1].waypointRelativePos = pos
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
            # Set the rotation target for point towards zones
            pointZone = self._pointZoneForWaypointPos(points[i].waypointRelativePos)
            if pointZone is not None:
                angleToTarget = (pointZone.targetPosition - points[i].position).angle()
                rotation = angleToTarget + pointZone.rotationOffset
                points[i].rotationTarget = RotationTarget(points[i].waypointRelativePos, rotation)

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
