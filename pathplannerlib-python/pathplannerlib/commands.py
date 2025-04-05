import math
from math import hypot

from .controller import *
from .path import PathPlannerPath, GoalEndState, PathConstraints, IdealStartingState
from .trajectory import PathPlannerTrajectory
from .telemetry import PPLibTelemetry
from .logging import PathPlannerLogging
from .util import floatLerp, FlippingUtil, DriveFeedforwards
from wpimath.geometry import Pose2d, Rotation2d
from wpimath.kinematics import ChassisSpeeds
from wpilib import Timer
from commands2 import Command, Subsystem, SequentialCommandGroup, DeferredCommand
import commands2.cmd as cmd
from typing import Callable
from .config import RobotConfig
from .pathfinding import Pathfinding
from .events import EventScheduler
from hal import report, tResourceType


class FollowPathCommand(Command):
    _originalPath: PathPlannerPath
    _poseSupplier: Callable[[], Pose2d]
    _speedsSupplier: Callable[[], ChassisSpeeds]
    _output: Callable[[ChassisSpeeds, DriveFeedforwards], None]
    _controller: PathFollowingController
    _robotConfig: RobotConfig
    _shouldFlipPath: Callable[[], bool]

    _eventScheduler: EventScheduler

    _timer: Timer = Timer()

    _path: PathPlannerPath = None
    _trajectory: PathPlannerTrajectory = None

    currentPathName: str = ''

    def __init__(self, path: PathPlannerPath, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds],
                 output: Callable[[ChassisSpeeds, DriveFeedforwards], None],
                 controller: PathFollowingController, robot_config: RobotConfig,
                 should_flip_path: Callable[[], bool], *requirements: Subsystem):
        """
        Construct a base path following command

        :param path: The path to follow
        :param pose_supplier: Function that supplies the current field-relative pose of the robot
        :param speeds_supplier: Function that supplies the current robot-relative chassis speeds
        :param output: Output function that accepts robot-relative ChassisSpeeds and feedforwards for
            each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
            using a differential drive, they will be in L, R order.
            <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
            module states, you will need to reverse the feedforwards for modules that have been flipped
        :param controller: Path following controller that will be used to follow the path
        :param robot_config The robot configuration
        :param should_flip_path: Should the path be flipped to the other side of the field? This will maintain a global blue alliance origin.
        :param requirements: Subsystems required by this command, usually just the drive subsystem
        """
        super().__init__()

        self._originalPath = path
        self._poseSupplier = pose_supplier
        self._speedsSupplier = speeds_supplier
        self._output = output
        self._controller = controller
        self._robotConfig = robot_config
        self._shouldFlipPath = should_flip_path
        self._eventScheduler = EventScheduler()

        self.addRequirements(*requirements)

        eventReqs = EventScheduler.getSchedulerRequirements(self._originalPath)
        for req in requirements:
            if req in eventReqs:
                raise RuntimeError(
                    'Events that are triggered during path following cannot require the drive subsystem')
        self.addRequirements(*eventReqs)

        self._path = self._originalPath
        # Ensure the ideal trajectory is generated
        idealTrajectory = self._path.getIdealTrajectory(self._robotConfig)
        if idealTrajectory is not None:
            self._trajectory = idealTrajectory

    def initialize(self):
        FollowPathCommand.currentPathName = self._originalPath.name
        if self._shouldFlipPath() and not self._originalPath.preventFlipping:
            self._path = self._originalPath.flipPath()
        else:
            self._path = self._originalPath

        currentPose = self._poseSupplier()
        currentSpeeds = self._speedsSupplier()

        self._controller.reset(currentPose, currentSpeeds)

        linearVel = math.hypot(currentSpeeds.vx, currentSpeeds.vy)

        if self._path.getIdealStartingState() is not None:
            # Check if we match the ideal starting state
            idealVelocity = abs(linearVel - self._path.getIdealStartingState().velocity) <= 0.25
            idealRotation = (not self._robotConfig.isHolonomic) or abs(
                (currentPose.rotation() - self._path.getIdealStartingState().rotation).degrees()) <= 30.0
            if idealVelocity and idealRotation:
                # We can use the ideal trajectory
                self._trajectory = self._path.getIdealTrajectory(self._robotConfig)
            else:
                # We need to regenerate
                self._trajectory = self._path.generateTrajectory(currentSpeeds, currentPose.rotation(),
                                                                 self._robotConfig)
        else:
            # No ideal starting state, generate the trajectory
            self._trajectory = self._path.generateTrajectory(currentSpeeds, currentPose.rotation(), self._robotConfig)

        PathPlannerLogging.logActivePath(self._path)
        PPLibTelemetry.setCurrentPath(self._path)

        self._eventScheduler.initialize(self._trajectory)

        self._timer.reset()
        self._timer.start()

    def execute(self):
        currentTime = self._timer.get()
        targetState = self._trajectory.sample(currentTime)
        if not self._controller.isHolonomic() and self._path.isReversed():
            targetState = targetState.reverse()

        currentPose = self._poseSupplier()
        currentSpeeds = self._speedsSupplier()

        targetSpeeds = self._controller.calculateRobotRelativeSpeeds(currentPose, targetState)

        currentVel = math.hypot(currentSpeeds.vx, currentSpeeds.vy)

        PPLibTelemetry.setCurrentPose(currentPose)
        PathPlannerLogging.logCurrentPose(currentPose)

        PPLibTelemetry.setTargetPose(targetState.pose)
        PathPlannerLogging.logTargetPose(targetState.pose)

        PPLibTelemetry.setVelocities(currentVel, targetState.linearVelocity, currentSpeeds.omega, targetSpeeds.omega)

        self._output(targetSpeeds, targetState.feedforwards)

        self._eventScheduler.execute(currentTime)

    def isFinished(self) -> bool:
        totalTime = self._trajectory.getTotalTimeSeconds()
        return self._timer.hasElapsed(totalTime) or not math.isfinite(totalTime)

    def end(self, interrupted: bool):
        self._timer.stop()
        FollowPathCommand.currentPathName = ''

        # Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
        # the command to smoothly transition into some auto-alignment routine
        if not interrupted and self._path.getGoalEndState().velocity < 0.1:
            self._output(ChassisSpeeds(), DriveFeedforwards.zeros(self._robotConfig.numModules))

        PathPlannerLogging.logActivePath(None)

        self._eventScheduler.end()


class PathfindingCommand(Command):
    _timer: Timer = Timer()
    _targetPath: Union[PathPlannerPath, None]
    _targetPose: Pose2d
    _originalTargetPose: Pose2d
    _goalEndState: GoalEndState
    _constraints: PathConstraints
    _poseSupplier: Callable[[], Pose2d]
    _speedsSupplier: Callable[[], ChassisSpeeds]
    _output: Callable[[ChassisSpeeds, DriveFeedforwards], None]
    _controller: PathFollowingController
    _robotConfig: RobotConfig
    _shouldFlipPath: Callable[[], bool]

    _currentPath: Union[PathPlannerPath, None]
    _currentTrajectory: Union[PathPlannerTrajectory, None]

    _timeOffset: float = 0

    _finish: bool = False

    _instances: int = 0

    def __init__(self, constraints: PathConstraints, pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds],
                 output: Callable[[ChassisSpeeds, DriveFeedforwards], None],
                 controller: PathFollowingController, robot_config: RobotConfig,
                 should_flip_path: Callable[[], bool], *requirements: Subsystem,
                 target_path: PathPlannerPath = None, target_pose: Pose2d = None,
                 goal_end_vel: float = 0):
        """
        Construct a pathfinding command

        :param constraints: The constraints to use while path following
        :param pose_supplier: Function that supplies the current field-relative pose of the robot
        :param speeds_supplier: Function that supplies the current robot-relative chassis speeds
        :param output: Output function that accepts robot-relative ChassisSpeeds and feedforwards for
            each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
            using a differential drive, they will be in L, R order.
            <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
            module states, you will need to reverse the feedforwards for modules that have been flipped
        :param controller: Path following controller that will be used to follow the path
        :param robot_config The robot configuration
        :param should_flip_path: Should the path be flipped to the other side of the field? This will maintain a global blue alliance origin.
        :param requirements: Subsystems required by this command, usually just the drive subsystem
        :param target_path: The path to pathfind to. This should be None if target_pose is specified
        :param target_pose: The pose to pathfind to. This should be None if target_path is specified
        :param goal_end_vel: The goal end velocity when reaching the target path/pose
        """
        super().__init__()
        if target_path is None and target_pose is None:
            raise ValueError('Either target_path or target_pose must be specified for PathfindingCommand')

        self.addRequirements(*requirements)

        Pathfinding.ensureInitialized()

        self._constraints = constraints
        self._controller = controller
        self._poseSupplier = pose_supplier
        self._speedsSupplier = speeds_supplier
        self._output = output
        self._robotConfig = robot_config
        self._shouldFlipPath = should_flip_path

        if target_path is not None:
            targetRotation = Rotation2d()
            goalEndVel = target_path.getGlobalConstraints().maxVelocityMps
            if target_path.isChoreoPath():
                # Can use ideal trajectory here without issue since all choreo paths have an ideal trajectory
                choreoTraj = target_path.getIdealTrajectory(self._robotConfig)
                targetRotation = choreoTraj.getInitialState().pose.rotation()
                goalEndVel = choreoTraj.getInitialState().linearVelocity
            else:
                for p in target_path.getAllPathPoints():
                    if p.rotationTarget is not None:
                        targetRotation = p.rotationTarget.target
                        break
            self._targetPath = target_path
            self._targetPose = Pose2d(target_path.getPoint(0).position, targetRotation)
            self._originalTargetPose = Pose2d(target_path.getPoint(0).position, targetRotation)
            self._goalEndState = GoalEndState(goalEndVel, targetRotation)
        else:
            self._targetPath = None
            self._targetPose = target_pose
            self._originalTargetPose = target_pose
            self._goalEndState = GoalEndState(goal_end_vel, target_pose.rotation())

        PathfindingCommand._instances += 1
        report(tResourceType.kResourceType_PathFindingCommand.value, PathfindingCommand._instances)

    def initialize(self):
        self._currentTrajectory = None
        self._timeOffset = 0.0
        self._finish = False

        currentPose = self._poseSupplier()

        self._controller.reset(currentPose, self._speedsSupplier())

        if self._targetPath is not None:
            self._originalTargetPose = Pose2d(self._targetPath.getPoint(0).position,
                                              self._originalTargetPose.rotation())
            if self._shouldFlipPath():
                self._targetPose = FlippingUtil.flipFieldPose(self._originalTargetPose)
                self._goalEndState = GoalEndState(self._goalEndState.velocity, self._targetPose.rotation())

        if currentPose.translation().distance(self._targetPose.translation()) < 0.5:
            self._output(ChassisSpeeds(), DriveFeedforwards.zeros(self._robotConfig.numModules))
            self._finish = True
        else:
            Pathfinding.setStartPosition(currentPose.translation())
            Pathfinding.setGoalPosition(self._targetPose.translation())

    def execute(self):
        if self._finish:
            return

        currentPose = self._poseSupplier()
        currentSpeeds = self._speedsSupplier()

        PathPlannerLogging.logCurrentPose(currentPose)
        PPLibTelemetry.setCurrentPose(currentPose)

        # Skip new paths if we are close to the end
        skipUpdates = self._currentTrajectory is not None and currentPose.translation().distance(
            self._currentTrajectory.getEndState().pose.translation()) < 2.0

        if not skipUpdates and Pathfinding.isNewPathAvailable():
            self._currentPath = Pathfinding.getCurrentPath(self._constraints, self._goalEndState)

            if self._currentPath is not None:
                self._currentTrajectory = PathPlannerTrajectory(self._currentPath, currentSpeeds,
                                                                currentPose.rotation(), self._robotConfig)
                if not math.isfinite(self._currentTrajectory.getTotalTimeSeconds()):
                    self._finish = True
                    return

                # Find the two closest states in front of and behind robot
                closestState1Idx = 0
                closestState2Idx = 1
                while closestState2Idx < len(self._currentTrajectory.getStates()) - 1:
                    closest2Dist = self._currentTrajectory.getState(closestState2Idx).pose.translation().distance(
                        currentPose.translation())
                    nextDist = self._currentTrajectory.getState(closestState2Idx + 1).pose.translation().distance(
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

                d = closestState1.pose.translation().distance(closestState2.pose.translation())
                t = (currentPose.translation().distance(closestState1.pose.translation())) / d
                t = min(1.0, max(0.0, t))

                self._timeOffset = floatLerp(closestState1.timeSeconds, closestState2.timeSeconds, t)

                # If the robot is stationary and at the start of the path, set the time offset to the
                # next loop
                # This can prevent an issue where the robot will remain stationary if new paths come in
                # every loop

                if self._timeOffset <= 0.02 and math.hypot(currentSpeeds.vx, currentSpeeds.vy) < 0.1:
                    self._timeOffset = 0.02

                PathPlannerLogging.logActivePath(self._currentPath)
                PPLibTelemetry.setCurrentPath(self._currentPath)

            self._timer.reset()
            self._timer.start()

        if self._currentTrajectory is not None:
            targetState = self._currentTrajectory.sample(self._timer.get() + self._timeOffset)

            targetSpeeds = self._controller.calculateRobotRelativeSpeeds(currentPose, targetState)

            currentVel = math.hypot(currentSpeeds.vx, currentSpeeds.vy)

            PPLibTelemetry.setCurrentPose(currentPose)
            PathPlannerLogging.logCurrentPose(currentPose)

            PPLibTelemetry.setTargetPose(targetState.pose)
            PathPlannerLogging.logTargetPose(targetState.pose)

            PPLibTelemetry.setVelocities(currentVel, targetState.linearVelocity, currentSpeeds.omega,
                                         targetSpeeds.omega)

            self._output(targetSpeeds, targetState.feedforwards)

    def isFinished(self) -> bool:
        if self._finish:
            return True

        if self._targetPath is not None and not self._targetPath.isChoreoPath():
            currentPose = self._poseSupplier()
            currentSpeeds = self._speedsSupplier()

            currentVel = math.hypot(currentSpeeds.vx, currentSpeeds.vy)
            stoppingDistance = (currentVel ** 2) / (2 * self._constraints.maxAccelerationMpsSq)

            return currentPose.translation().distance(self._targetPose.translation()) <= stoppingDistance

        if self._currentTrajectory is not None:
            return self._timer.hasElapsed(self._currentTrajectory.getTotalTimeSeconds() - self._timeOffset)

        return False

    def end(self, interrupted: bool):
        self._timer.stop()

        # Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
        # the command to smoothly transition into some auto-alignment routine
        if not interrupted and self._goalEndState.velocity < 0.1:
            self._output(ChassisSpeeds(), DriveFeedforwards.zeros(self._robotConfig.numModules))

        PathPlannerLogging.logActivePath(None)


class PathfindThenFollowPath(SequentialCommandGroup):
    def __init__(self, goal_path: PathPlannerPath, pathfinding_constraints: PathConstraints,
                 pose_supplier: Callable[[], Pose2d],
                 speeds_supplier: Callable[[], ChassisSpeeds],
                 output: Callable[[ChassisSpeeds, DriveFeedforwards], None],
                 controller: PathFollowingController, robot_config: RobotConfig,
                 should_flip_path: Callable[[], bool], *requirements: Subsystem):
        """
        Constructs a new PathfindThenFollowPath command group.

        :param goal_path: the goal path to follow
        :param pathfinding_constraints: the path constraints for pathfinding
        :param pose_supplier: a supplier for the robot's current pose
        :param speeds_supplier: a supplier for the robot's current robot relative speeds
        :param output: Output function that accepts robot-relative ChassisSpeeds and feedforwards for
            each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
            using a differential drive, they will be in L, R order.
            <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
            module states, you will need to reverse the feedforwards for modules that have been flipped
        :param controller Path following controller that will be used to follow the path
        :param robot_config The robot configuration
        :param should_flip_path: Should the path be flipped to the other side of the field? This will maintain a global blue alliance origin.
        :param requirements: the subsystems required by this command (drive subsystem)
        """
        super().__init__()

        def buildJoinCommand() -> Command:
            if goal_path.numPoints() < 2:
                return cmd.none()

            startPose = pose_supplier()
            startSpeeds = speeds_supplier()
            startFieldSpeeds = ChassisSpeeds.fromRobotRelativeSpeeds(startSpeeds, startPose.rotation())

            startHeading = Rotation2d(startFieldSpeeds.vx, startFieldSpeeds.vy)

            endWaypoint = Pose2d(goal_path.getPoint(0).position, goal_path.getInitialHeading())
            shouldFlip = should_flip_path() and not goal_path.preventFlipping
            if shouldFlip:
                endWaypoint = FlippingUtil.flipFieldPose(endWaypoint)

            endState = GoalEndState(pathfinding_constraints.maxVelocityMps, startPose.rotation())
            if goal_path.getIdealStartingState() is not None:
                endRot = goal_path.getIdealStartingState().rotation
                if shouldFlip:
                    endRot = FlippingUtil.flipFieldRotation(endRot)
                endState = GoalEndState(goal_path.getIdealStartingState().velocity, endRot)

            joinPath = PathPlannerPath(
                PathPlannerPath.waypointsFromPoses([Pose2d(startPose.translation(), startHeading), endWaypoint]),
                pathfinding_constraints,
                IdealStartingState(hypot(startSpeeds.vx, startSpeeds.vy), startPose.rotation()),
                endState
            )
            joinPath.preventFlipping = True

            return FollowPathCommand(
                joinPath,
                pose_supplier,
                speeds_supplier,
                output,
                controller,
                robot_config,
                should_flip_path,
                *requirements
            )

        self.addCommands(
            PathfindingCommand(
                pathfinding_constraints,
                pose_supplier,
                speeds_supplier,
                output,
                controller,
                robot_config,
                should_flip_path,
                *requirements,
                target_path=goal_path
            ),
            DeferredCommand(buildJoinCommand, requirements),
            FollowPathCommand(
                goal_path,
                pose_supplier,
                speeds_supplier,
                output,
                controller,
                robot_config,
                should_flip_path,
                *requirements
            )
        )
