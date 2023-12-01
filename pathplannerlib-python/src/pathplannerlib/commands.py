import math

from controller import *
from path import PathPlannerPath, EventMarker
from trajectory import PathPlannerTrajectory
from telemetry import PPLibTelemetry
from .logging import PathPlannerLogging
from wpimath.geometry import Pose2d
from wpimath.kinematics import ChassisSpeeds
from wpilib import Timer
from commands2 import Command, Subsystem
from typing import Callable, Tuple, List
from config import ReplanningConfig, HolonomicPathFollowerConfig


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

        if self._replanningConfig.enableInitialReplanning and (
                currentPose.translation().distance(self._path.getPoint(0).position) >= 0.25 or math.hypot(
            currentSpeeds.vx, currentSpeeds.vy) >= 0.25):
            self._replanPath(currentPose, currentSpeeds)
        else:
            self._generatedTrajectory = PathPlannerTrajectory(self._path, currentSpeeds, currentPose.rotation())
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

        if self._replanningConfig.enableDynamicReplanning:
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


class FollowPathLTV(FollowPathCommand):
    def __init__(self, path: PathPlannerPath, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds], output_robot_relative: Callable[[ChassisSpeeds], None],
                 qelems: Tuple[float, float, float], relems: Tuple[float, float], dt: float,
                 replanning_config: ReplanningConfig, *requirements: Subsystem):
        """
        Construct a path following command that will use a Ramsete path following controller for differential drive trains

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
