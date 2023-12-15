import math

from .controller import *
from .path import PathPlannerPath, EventMarker, GoalEndState, PathConstraints
from .trajectory import PathPlannerTrajectory
from .telemetry import PPLibTelemetry
from .logging import PathPlannerLogging
from .geometry_util import floatLerp
from wpimath.geometry import Pose2d
from wpimath.kinematics import ChassisSpeeds
from wpilib import Timer
from commands2 import Command, Subsystem, SequentialCommandGroup
from typing import Callable, Tuple, List
from .config import ReplanningConfig, HolonomicPathFollowerConfig
from .pathfinding import Pathfinding
from hal import report


class FollowPathWithEvents(Command):
    _pathFollowingCommand: Command
    _path: PathPlannerPath
    _poseSupplier: Callable[[], Pose2d]

    _currentCommands: dict = {}
    _untriggeredMarkers: List[EventMarker] = []
    _isFinished: bool = False

    def __init__(self, path_following_command: Command, path: PathPlannerPath, pose_supplier: Callable[[], Pose2d]):
        """
        Constructs a new FollowPathWithEvents command.

        :param path_following_command: the command to follow the path
        :param path: the path to follow
        :param pose_supplier: a supplier for the robot's current pose
        """
        super().__init__()
        self._pathFollowingCommand = path_following_command
        self._path = path
        self._poseSupplier = pose_supplier

        self.addRequirements(*self._pathFollowingCommand.getRequirements())
        for marker in self._path.getEventMarkers():
            reqs = marker.command.getRequirements()

            for req in self._pathFollowingCommand.getRequirements():
                if req in reqs:
                    raise RuntimeError(
                        'Events that are triggered during path following cannot require the drive subsystem')

            self.addRequirements(*reqs)

    def initialize(self):
        self._isFinished = False

        self._currentCommands.clear()

        currentPose = self._poseSupplier()
        for marker in self._path.getEventMarkers():
            marker.reset(currentPose)

        self._untriggeredMarkers.clear()
        for marker in self._path.getEventMarkers():
            self._untriggeredMarkers.append(marker)

        self._pathFollowingCommand.initialize()
        self._currentCommands[self._pathFollowingCommand] = True

    def execute(self):
        for command in self._currentCommands:
            if not self._currentCommands[command]:
                continue

            command.execute()

            if command.isFinished():
                command.end(False)
                self._currentCommands[command] = False
                if command == self._pathFollowingCommand:
                    self._isFinished = True

        currentPose = self._poseSupplier()
        toTrigger = [marker for marker in self._untriggeredMarkers if marker.shouldTrigger(currentPose)]

        for marker in toTrigger:
            self._untriggeredMarkers.remove(marker)

        for marker in toTrigger:
            for command in self._currentCommands:
                if not self._currentCommands[command]:
                    continue

                for req in command.getRequirements():
                    if req in marker.command.getRequirements():
                        command.end(True)
                        self._currentCommands[command] = False
                        break

            marker.command.initialize()
            self._currentCommands[marker.command] = True

    def isFinished(self) -> bool:
        return self._isFinished

    def end(self, interrupted: bool):
        for command in self._currentCommands:
            if self._currentCommands[command]:
                command.end(True)


class FollowPathCommand(Command):
    _path: PathPlannerPath
    _poseSupplier: Callable[[], Pose2d]
    _speedsSupplier: Callable[[], ChassisSpeeds]
    _output: Callable[[ChassisSpeeds], None]
    _controller: PathFollowingController
    _replanningConfig: ReplanningConfig

    _timer: Timer = Timer()
    _generatedTrajectory: PathPlannerTrajectory = None

    def __init__(self, path: PathPlannerPath, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 controller: PathFollowingController, replanning_config: ReplanningConfig, *requirements: Subsystem):
        """
        Construct a base path following command

        :param path: The path to follow
        :param pose_supplier: Function that supplies the current field-relative pose of the robot
        :param speeds_supplier: Function that supplies the current robot-relative chassis speeds
        :param output_robot_relative: Function that will apply the robot-relative output speeds of this command
        :param controller: Path following controller that will be used to follow the path
        :param replanning_config: Path replanning configuration
        :param requirements: Subsystems required by this command, usually just the drive subsystem
        """
        super().__init__()

        self._path = path
        self._poseSupplier = pose_supplier
        self._speedsSupplier = speeds_supplier
        self._output = output_robot_relative
        self._controller = controller
        self._replanningConfig = replanning_config

        self.addRequirements(*requirements)

    def initialize(self):
        currentPose = self._poseSupplier()
        currentSpeeds = self._speedsSupplier()

        self._controller.reset(currentPose, currentSpeeds)

        fieldSpeeds = ChassisSpeeds.fromRobotRelativeSpeeds(currentSpeeds, currentPose.rotation())
        currentHeading = Rotation2d(fieldSpeeds.vx, fieldSpeeds.vy)
        targetHeading = (self._path.getPoint(1).position - self._path.getPoint(0).position).angle()
        headingError = currentHeading - targetHeading
        onHeading = math.hypot(currentSpeeds.vx, currentSpeeds.vy) < 0.25 or abs(headingError.degrees()) < 30

        if not self._path.isChoreoPath() and self._replanningConfig.enableInitialReplanning and not (
                currentPose.translation().distance(self._path.getPoint(0).position) < 0.25 and onHeading):
            self._replanPath(currentPose, currentSpeeds)
        else:
            self._generatedTrajectory = self._path.getTrajectory(currentSpeeds, currentPose.rotation())
            PathPlannerLogging.logActivePath(self._path)
            PPLibTelemetry.setCurrentPath(self._path)

        self._timer.reset()
        self._timer.start()

    def execute(self):
        currentTime = self._timer.get()
        targetState = self._generatedTrajectory.sample(currentTime)
        if not self._controller.isHolonomic() and self._path.isReversed():
            targetState = targetState.reverse()

        currentPose = self._poseSupplier()
        currentSpeeds = self._speedsSupplier()

        if not self._path.isChoreoPath() and self._replanningConfig.enableDynamicReplanning:
            previousError = abs(self._controller.getPositionalError())
            currentError = currentPose.translation().distance(targetState.positionMeters)

            if currentError >= self._replanningConfig.dynamicReplanningTotalErrorThreshold or currentError - previousError >= self._replanningConfig.dynamicReplanningErrorSpikeThreshold:
                self._replanPath(currentPose, currentSpeeds)
                self._timer.reset()
                targetState = self._generatedTrajectory.sample(0.0)

        targetSpeeds = self._controller.calculateRobotRelativeSpeeds(currentPose, targetState)

        currentVel = math.hypot(currentSpeeds.vx, currentSpeeds.vy)

        PPLibTelemetry.setCurrentPose(currentPose)
        PathPlannerLogging.logCurrentPose(currentPose)

        if self._controller.isHolonomic():
            PPLibTelemetry.setTargetPose(targetState.getTargetHolonomicPose())
            PathPlannerLogging.logTargetPose(targetState.getTargetHolonomicPose())
        else:
            PPLibTelemetry.setTargetPose(targetState.getDifferentialPose())
            PathPlannerLogging.logTargetPose(targetState.getDifferentialPose())

        PPLibTelemetry.setVelocities(currentVel, targetState.velocityMps, currentSpeeds.omega, targetSpeeds.omega)
        PPLibTelemetry.setPathInaccuracy(self._controller.getPositionalError())

        self._output(targetSpeeds)

    def isFinished(self) -> bool:
        return self._timer.hasElapsed(self._generatedTrajectory.getTotalTimeSeconds())

    def end(self, interrupted: bool):
        self._timer.stop()

        # Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
        # the command to smoothly transition into some auto-alignment routine
        if not interrupted and self._path.getGoalEndState().velocity < 0.1:
            self._output(ChassisSpeeds())

        PathPlannerLogging.logActivePath(None)

    def _replanPath(self, current_pose: Pose2d, current_speeds: ChassisSpeeds) -> None:
        replanned = self._path.replan(current_pose, current_speeds)
        self._generatedTrajectory = PathPlannerTrajectory(replanned, current_speeds, current_pose.rotation())
        PathPlannerLogging.logActivePath(replanned)
        PPLibTelemetry.setCurrentPath(replanned)


class FollowPathHolonomic(FollowPathCommand):
    def __init__(self, path: PathPlannerPath, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 config: HolonomicPathFollowerConfig, *requirements: Subsystem):
        """
        Construct a path following command that will use a holonomic drive controller for holonomic drive trains

        :param path: The path to follow
        :param pose_supplier: Function that supplies the current field-relative pose of the robot
        :param speeds_supplier: Function that supplies the current robot-relative chassis speeds
        :param output_robot_relative: Function that will apply the robot-relative output speeds of this command
        :param config: Holonomic path follower configuration
        :param requirements: Subsystems required by this command, usually just the drive subsystem
        """
        super().__init__(path, pose_supplier, speeds_supplier, output_robot_relative, PPHolonomicDriveController(
            config.translationConstants, config.rotationConstants, config.maxModuleSpeed, config.driveBaseRadius,
            config.period
        ), config.replanningConfig, *requirements)


class FollowPathRamsete(FollowPathCommand):
    def __init__(self, path: PathPlannerPath, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 replanning_config: ReplanningConfig, *requirements: Subsystem):
        """
        Construct a path following command that will use a Ramsete path following controller for differential drive trains

        :param path: The path to follow
        :param pose_supplier: Function that supplies the current field-relative pose of the robot
        :param speeds_supplier: Function that supplies the current robot-relative chassis speeds
        :param output_robot_relative: Function that will apply the robot-relative output speeds of this command
        :param replanning_config: Path replanning configuration
        :param requirements: Subsystems required by this command, usually just the drive subsystem
        """
        super().__init__(path, pose_supplier, speeds_supplier, output_robot_relative, PPRamseteController(),
                         replanning_config, *requirements)

        if path.isChoreoPath():
            raise ValueError('Paths loaded from Choreo cannot be used with differential drivetrains')


class FollowPathLTV(FollowPathCommand):
    def __init__(self, path: PathPlannerPath, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 qelems: Tuple[float, float, float], relems: Tuple[float, float], dt: float,
                 replanning_config: ReplanningConfig, *requirements: Subsystem):
        """
        Construct a path following command that will use a LTV path following controller for differential drive trains

        :param path: The path to follow
        :param pose_supplier: Function that supplies the current field-relative pose of the robot
        :param speeds_supplier: Function that supplies the current robot-relative chassis speeds
        :param output_robot_relative: Function that will apply the robot-relative output speeds of this command
        :param qelems: The maximum desired error tolerance for each state
        :param relems: The maximum desired control effort for each input
        :param dt: The amount of time between each robot control loop, default is 0.02s
        :param replanning_config: Path replanning configuration
        :param requirements: Subsystems required by this command, usually just the drive subsystem
        """
        super().__init__(path, pose_supplier, speeds_supplier, output_robot_relative,
                         PPLTVController(qelems, relems, dt),
                         replanning_config, *requirements)

        if path.isChoreoPath():
            raise ValueError('Paths loaded from Choreo cannot be used with differential drivetrains')


class PathfindingCommand(Command):
    _timer: Timer = Timer()
    _targetPath: Union[PathPlannerPath, None]
    _targetPose: Pose2d
    _goalEndState: GoalEndState
    _constraints: PathConstraints
    _poseSupplier: Callable[[], Pose2d]
    _speedsSupplier: Callable[[], ChassisSpeeds]
    _output: Callable[[ChassisSpeeds], None]
    _controller: PathFollowingController
    _rotationDelayDistance: float
    _replanningConfig: ReplanningConfig

    _currentPath: Union[PathPlannerPath, None]
    _currentTrajectory: Union[PathPlannerTrajectory, None]
    _startingPose: Pose2d

    _timeOffset: float = 0

    _instances: int = 0

    def __init__(self, constraints: PathConstraints, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 controller: PathFollowingController, replanning_config: ReplanningConfig, *requirements: Subsystem,
                 rotation_delay_distance: float = 0.0, target_path: PathPlannerPath = None, target_pose: Pose2d = None,
                 goal_end_vel: float = 0):
        super().__init__()
        if target_path is None and target_pose is None:
            raise ValueError('Either target_path or target_pose must be specified for PathfindingCommand')

        self.addRequirements(*requirements)

        Pathfinding.ensureInitialized()

        self._constraints = constraints
        self._controller = controller
        self._poseSupplier = pose_supplier
        self._speedsSupplier = speeds_supplier
        self._output = output_robot_relative
        self._rotationDelayDistance = rotation_delay_distance
        self._replanningConfig = replanning_config

        if target_path is not None:
            targetRotation = Rotation2d()
            goalEndVel = target_path.getGlobalConstraints().maxVelocityMps
            if target_path.isChoreoPath():
                # Can call getTrajectory here without proper speeds since it will just return the choreo
                # trajectory
                choreoTraj = target_path.getTrajectory(ChassisSpeeds(), Rotation2d())
                targetRotation = choreoTraj.getInitialState().targetHolonomicRotation
                goalEndVel = choreoTraj.getInitialState().velocityMps
            else:
                for p in target_path.getAllPathPoints():
                    if p.rotationTarget is not None:
                        targetRotation = p.rotationTarget.target
                        break
            self._targetPath = target_path
            self._targetPose = Pose2d(target_path.getPoint(0).position, targetRotation)
            self._goalEndState = GoalEndState(goalEndVel, targetRotation, True)
        else:
            self._targetPath = None
            self._targetPose = target_pose
            self._goalEndState = GoalEndState(goal_end_vel, target_pose.rotation(), True)

        PathfindingCommand._instances += 1
        report(108, PathfindingCommand._instances)  # TODO: Use resource type when updated

    def initialize(self):
        self._currentTrajectory = None
        self._timeOffset = 0.0

        currentPose = self._poseSupplier()

        self._controller.reset(currentPose, self._speedsSupplier())

        if self._targetPath is not None:
            self._targetPose = Pose2d(self._targetPath.getPoint(0).position, self._goalEndState.rotation)

        if currentPose.translation().distance(self._targetPose.translation()) < 0.25:
            self.cancel()
        else:
            Pathfinding.setStartPosition(currentPose.translation())
            Pathfinding.setGoalPosition(self._targetPose.translation())

        self._startingPose = currentPose

    def execute(self):
        currentPose = self._poseSupplier()
        currentSpeeds = self._speedsSupplier()

        PathPlannerLogging.logCurrentPose(currentPose)
        PPLibTelemetry.setCurrentPose(currentPose)

        # Skip new paths if we are close to the end
        skipUpdates = self._currentTrajectory is not None and currentPose.translation().distance(
            self._currentTrajectory.getEndState().positionMeters) < 2.0

        if not skipUpdates and Pathfinding.isNewPathAvailable():
            self._currentPath = Pathfinding.getCurrentPath(self._constraints, self._goalEndState)

            if self._currentPath is not None:
                self._currentTrajectory = PathPlannerTrajectory(self._currentPath, currentSpeeds,
                                                                currentPose.rotation())

                # Find the two closest states in front of and behind robot
                closestState1Idx = 0
                closestState2Idx = 1
                while True:
                    closest2Dist = self._currentTrajectory.getState(closestState2Idx).positionMeters.distance(
                        currentPose.translation())
                    nextDist = self._currentTrajectory.getState(closestState2Idx + 1).positionMeters.distance(
                        currentPose.translation())

                    if nextDist < closest2Dist:
                        closestState1Idx += 1
                        closestState2Idx += 1
                    else:
                        break

                # Use the closest 2 states to interpolate what the time offset should be
                # This will account for the delay in pathfinding
                closestState1 = self._currentTrajectory.getState(closestState1Idx)
                closestState2 = self._currentTrajectory.getState(closestState2Idx)

                fieldRelativeSpeeds = ChassisSpeeds.fromRobotRelativeSpeeds(currentSpeeds, currentPose.rotation())
                currentHeading = Rotation2d(fieldRelativeSpeeds.vx, fieldRelativeSpeeds.vy)
                headingError = currentHeading - closestState1.heading
                onHeading = math.hypot(currentSpeeds.vx, currentSpeeds.vy) < 1.0 or abs(headingError.degrees()) < 30

                # Replan the path if we are more than 0.25m away or our heading is off
                if not onHeading or (
                        self._replanningConfig.enableInitialReplanning and currentPose.translation().distance(
                    closestState1.positionMeters) > 0.25):
                    self._currentPath = self._currentPath.replan(currentPose, currentSpeeds)
                    self._currentTrajectory = PathPlannerTrajectory(self._currentPath, currentSpeeds,
                                                                    currentPose.rotation())

                    self._timeOffset = 0.0
                else:
                    d = closestState1.positionMeters.distance(closestState2.positionMeters)
                    t = (currentPose.translation().distance(closestState1.positionMeters)) / d

                    self._timeOffset = floatLerp(closestState1.timeSeconds, closestState2.timeSeconds, t)

                PathPlannerLogging.logActivePath(self._currentPath)
                PPLibTelemetry.setCurrentPath(self._currentPath)

            self._timer.reset()
            self._timer.start()

        if self._currentTrajectory is not None:
            targetState = self._currentTrajectory.sample(self._timer.get() + self._timeOffset)

            if self._replanningConfig.enableDynamicReplanning:
                previousError = abs(self._controller.getPositionalError())
                currentError = currentPose.translation().distance(targetState.positionMeters)

                if currentError >= self._replanningConfig.dynamicReplanningTotalErrorThreshold or currentError - previousError >= self._replanningConfig.dynamicReplanningErrorSpikeThreshold:
                    replanned = self._currentPath.replan(currentPose, currentSpeeds)
                    self._currentTrajectory = PathPlannerTrajectory(replanned, currentSpeeds, currentPose.rotation())
                    PathPlannerLogging.logActivePath(replanned)
                    PPLibTelemetry.setCurrentPath(replanned)

                    self._timer.reset()
                    self._timeOffset = 0.0
                    targetState = self._currentTrajectory.sample(0.0)

            # Set the target rotation to the starting rotation if we have not yet traveled the rotation
            # delay distance
            if currentPose.translation().distance(self._startingPose.translation()) < self._rotationDelayDistance:
                targetState.targetHolonomicRotation = self._startingPose.rotation()

            targetSpeeds = self._controller.calculateRobotRelativeSpeeds(currentPose, targetState)

            currentVel = math.hypot(currentSpeeds.vx, currentSpeeds.vy)

            PPLibTelemetry.setCurrentPose(currentPose)
            PathPlannerLogging.logCurrentPose(currentPose)

            if self._controller.isHolonomic():
                PPLibTelemetry.setTargetPose(targetState.getTargetHolonomicPose())
                PathPlannerLogging.logTargetPose(targetState.getTargetHolonomicPose())
            else:
                PPLibTelemetry.setTargetPose(targetState.getDifferentialPose())
                PathPlannerLogging.logTargetPose(targetState.getDifferentialPose())

            PPLibTelemetry.setVelocities(currentVel, targetState.velocityMps, currentSpeeds.omega, targetSpeeds.omega)
            PPLibTelemetry.setPathInaccuracy(self._controller.getPositionalError())

            self._output(targetSpeeds)

    def isFinished(self) -> bool:
        if self._targetPath is not None and not self._targetPath.isChoreoPath():
            currentPose = self._poseSupplier()
            currentSpeeds = self._speedsSupplier()

            currentVel = math.hypot(currentSpeeds.vx, currentSpeeds.vy)
            stoppingDistance = (currentVel ** 2) / (2 * self._constraints.maxAccelerationMpsSq)

            return currentPose.translation().distance(self._targetPath.getPoint(0).position) <= stoppingDistance

        if self._currentTrajectory is not None:
            return self._timer.hasElapsed(self._currentTrajectory.getTotalTimeSeconds() - self._timeOffset)

        return False

    def end(self, interrupted: bool):
        self._timer.stop()

        # Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
        # the command to smoothly transition into some auto-alignment routine
        if not interrupted and self._goalEndState.velocity < 0.1:
            self._output(ChassisSpeeds())

        PathPlannerLogging.logActivePath(None)


class PathfindHolonomic(PathfindingCommand):
    def __init__(self, constraints: PathConstraints, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 config: HolonomicPathFollowerConfig, *requirements: Subsystem,
                 rotation_delay_distance: float = 0.0, target_path: PathPlannerPath = None, target_pose: Pose2d = None,
                 goal_end_vel: float = 0):
        """
        Constructs a new PathfindHolonomic command that will generate a path towards the given path or pose.
        NOTE: Either target_path or target_pose must be specified

        :param constraints: the path constraints to use while pathfinding
        :param pose_supplier: a supplier for the robot's current pose
        :param speeds_supplier: a supplier for the robot's current robot relative speeds
        :param output_robot_relative: a consumer for the output speeds (robot relative)
        :param config: HolonomicPathFollowerConfig object with the configuration parameters for path following
        :param requirements: the subsystems required by this command
        :param rotation_delay_distance: Distance to delay the target rotation of the robot. This will cause the robot to hold its current rotation until it reaches the given distance along the path.
        :param target_path: the path to pathfind to
        :param target_pose: the pose to pathfind to
        :param goal_end_vel: The goal end velocity when reaching the given pose
        """
        super().__init__(constraints, pose_supplier, speeds_supplier, output_robot_relative,
                         PPHolonomicDriveController(config.translationConstants, config.rotationConstants,
                                                    config.maxModuleSpeed, config.driveBaseRadius, config.period),
                         config.replanningConfig, *requirements, rotation_delay_distance=rotation_delay_distance,
                         target_path=target_path,
                         target_pose=target_pose, goal_end_vel=goal_end_vel)


class PathfindRamsete(PathfindingCommand):
    def __init__(self, constraints: PathConstraints, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 replanning_config: ReplanningConfig, *requirements: Subsystem,
                 target_path: PathPlannerPath = None, target_position: Translation2d = None,
                 goal_end_vel: float = 0):
        """
        Constructs a new PathfindRamsete command that will generate a path towards the given path or pose.
        NOTE: Either target_path or target_position must be specified.

        :param constraints: the path constraints to use while pathfinding
        :param pose_supplier: a supplier for the robot's current pose
        :param speeds_supplier: a supplier for the robot's current robot relative speeds
        :param output_robot_relative: a consumer for the output speeds (robot relative)
        :param replanning_config: Path replanning configuration
        :param requirements: the subsystems required by this command
        :param target_path: the path to pathfind to
        :param target_position: the position to pathfind to
        :param goal_end_vel: The goal end velocity when reaching the given position
        """
        super().__init__(constraints, pose_supplier, speeds_supplier, output_robot_relative,
                         PPRamseteController(), replanning_config, *requirements, target_path=target_path,
                         target_pose=Pose2d(target_position, Rotation2d()), goal_end_vel=goal_end_vel)

        if target_path is not None and target_path.isChoreoPath():
            raise ValueError('Paths loaded from Choreo cannot be used with differential drivetrains')


class PathfindLTV(PathfindingCommand):
    def __init__(self, constraints: PathConstraints, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 qelems: Tuple[float, float, float], relems: Tuple[float, float], dt: float,
                 replanning_config: ReplanningConfig, *requirements: Subsystem,
                 target_path: PathPlannerPath = None, target_position: Translation2d = None,
                 goal_end_vel: float = 0):
        """
        Constructs a new PathfindLTV command that will generate a path towards the given path or pose.
        NOTE: Either target_path or target_position must be specified.

        :param constraints: the path constraints to use while pathfinding
        :param pose_supplier: a supplier for the robot's current pose
        :param speeds_supplier: a supplier for the robot's current robot relative speeds
        :param output_robot_relative: a consumer for the output speeds (robot relative)
        :param qelems: The maximum desired error tolerance for each state
        :param relems: The maximum desired control effort for each input
        :param dt: The amount of time between each robot control loop, default is 0.02s
        :param replanning_config: Path replanning configuration
        :param requirements: the subsystems required by this command
        :param target_path: the path to pathfind to
        :param target_position: the position to pathfind to
        :param goal_end_vel: The goal end velocity when reaching the given position
        """
        super().__init__(constraints, pose_supplier, speeds_supplier, output_robot_relative,
                         PPLTVController(qelems, relems, dt), replanning_config, *requirements,
                         target_path=target_path, target_pose=Pose2d(target_position, Rotation2d()),
                         goal_end_vel=goal_end_vel)

        if target_path is not None and target_path.isChoreoPath():
            raise ValueError('Paths loaded from Choreo cannot be used with differential drivetrains')


class PathfindThenFollowPathHolonomic(SequentialCommandGroup):
    def __init__(self, goal_path: PathPlannerPath, pathfinding_constraints: PathConstraints,
                 pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 config: HolonomicPathFollowerConfig, *requirements: Subsystem, rotation_delay_distance: float = 0.0):
        """
        Constructs a new PathfindThenFollowPathHolonomic command group.

        :param goal_path: the goal path to follow
        :param pathfinding_constraints: the path constraints for pathfinding
        :param pose_supplier: a supplier for the robot's current pose
        :param speeds_supplier: a supplier for the robot's current robot relative speeds
        :param output_robot_relative: a consumer for the output speeds (robot relative)
        :param config: HolonomicPathFollowerConfig for configuring the path following commands
        :param requirements: the subsystems required by this command (drive subsystem)
        :param rotation_delay_distance: Distance to delay the target rotation of the robot. This will cause the robot to hold its current rotation until it reaches the given distance along the path.
        """
        super().__init__()

        self.addCommands(
            PathfindHolonomic(
                pathfinding_constraints,
                pose_supplier,
                speeds_supplier,
                output_robot_relative,
                config,
                *requirements,
                target_path=goal_path,
                rotation_delay_distance=rotation_delay_distance
            ),
            FollowPathWithEvents(
                FollowPathHolonomic(
                    goal_path,
                    pose_supplier,
                    speeds_supplier,
                    output_robot_relative,
                    config,
                    *requirements
                ),
                goal_path,
                pose_supplier
            )
        )


class PathfindThenFollowPathRamsete(SequentialCommandGroup):
    def __init__(self, goal_path: PathPlannerPath, pathfinding_constraints: PathConstraints,
                 pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 replanning_config: ReplanningConfig, *requirements: Subsystem):
        """
        Constructs a new PathfindThenFollowPathRamsete command group.

        :param goal_path: the goal path to follow
        :param pathfinding_constraints: the path constraints for pathfinding
        :param pose_supplier: a supplier for the robot's current pose
        :param speeds_supplier: a supplier for the robot's current robot relative speeds
        :param output_robot_relative: a consumer for the output speeds (robot relative)
        :param replanning_config: Path replanning configuration
        :param requirements: the subsystems required by this command (drive subsystem)
        """
        super().__init__()

        self.addCommands(
            PathfindRamsete(
                pathfinding_constraints,
                pose_supplier,
                speeds_supplier,
                output_robot_relative,
                replanning_config,
                *requirements,
                target_path=goal_path
            ),
            FollowPathWithEvents(
                FollowPathRamsete(
                    goal_path,
                    pose_supplier,
                    speeds_supplier,
                    output_robot_relative,
                    replanning_config,
                    *requirements
                ),
                goal_path,
                pose_supplier
            )
        )


class PathfindThenFollowPathLTV(SequentialCommandGroup):
    def __init__(self, goal_path: PathPlannerPath, pathfinding_constraints: PathConstraints,
                 pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 qelems: Tuple[float, float, float], relems: Tuple[float, float], dt: float,
                 replanning_config: ReplanningConfig, *requirements: Subsystem):
        """
        Constructs a new PathfindThenFollowPathRamsete command group.

        :param goal_path: the goal path to follow
        :param pathfinding_constraints: the path constraints for pathfinding
        :param pose_supplier: a supplier for the robot's current pose
        :param speeds_supplier: a supplier for the robot's current robot relative speeds
        :param output_robot_relative: a consumer for the output speeds (robot relative)
        :param qelems: The maximum desired error tolerance for each state
        :param relems: The maximum desired control effort for each input
        :param dt: The amount of time between each robot control loop, default is 0.02s
        :param replanning_config: Path replanning configuration
        :param requirements: the subsystems required by this command (drive subsystem)
        """
        super().__init__()

        self.addCommands(
            PathfindLTV(
                pathfinding_constraints,
                pose_supplier,
                speeds_supplier,
                output_robot_relative,
                qelems, relems, dt,
                replanning_config,
                *requirements,
                target_path=goal_path
            ),
            FollowPathWithEvents(
                FollowPathLTV(
                    goal_path,
                    pose_supplier,
                    speeds_supplier,
                    output_robot_relative,
                    qelems, relems, dt,
                    replanning_config,
                    *requirements
                ),
                goal_path,
                pose_supplier
            )
        )
