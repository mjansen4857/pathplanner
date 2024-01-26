from commands2.functionalcommand import FunctionalCommand
import commands2.cmd as cmd
from .path import PathPlannerPath, PathConstraints
from typing import Callable, Tuple, List
from wpimath.geometry import Pose2d, Rotation2d
from wpimath.kinematics import ChassisSpeeds
from .commands import FollowPathRamsete, FollowPathHolonomic, FollowPathLTV, PathfindLTV, \
    PathfindHolonomic, PathfindRamsete, PathfindThenFollowPathHolonomic, PathfindThenFollowPathRamsete, \
    PathfindThenFollowPathLTV
from .geometry_util import flipFieldPose
import os
from wpilib import getDeployDirectory, reportError, reportWarning
import json
from commands2.command import Command
from commands2.subsystem import Subsystem
from .config import HolonomicPathFollowerConfig, ReplanningConfig
from hal import report, tResourceType


class NamedCommands:
    _namedCommands: dict = {}

    @staticmethod
    def registerCommand(name: str, command: Command) -> None:
        """
        Registers a command with the given name

        :param name: the name of the command
        :param command: the command to register
        """
        NamedCommands._namedCommands[name] = command

    @staticmethod
    def hasCommand(name: str) -> bool:
        """
        Returns whether a command with the given name has been registered.

        :param name: the name of the command to check
        :return: true if a command with the given name has been registered, false otherwise
        """
        return name in NamedCommands._namedCommands

    @staticmethod
    def getCommand(name: str) -> Command:
        """
        Returns the command with the given name.

        :param name: the name of the command to get
        :return: the command with the given name, wrapped in a functional command, or a none command if it has not been registered
        """
        if NamedCommands.hasCommand(name):
            return CommandUtil.wrappedEventCommand(NamedCommands._namedCommands[name])
        else:
            reportWarning(f"PathPlanner attempted to create a command '{name}' that has not been registered with NamedCommands.registerCommand", False)
            return cmd.none()


class CommandUtil:
    @staticmethod
    def wrappedEventCommand(event_command: Command) -> Command:
        """
        Wraps a command with a functional command that calls the command's initialize, execute, end,
        and isFinished methods. This allows a command in the event map to be reused multiple times in
        different command groups

        :param event_command: the command to wrap
        :return: a functional command that wraps the given command
        """
        return FunctionalCommand(
            lambda: event_command.initialize(),
            lambda: event_command.execute(),
            lambda interupted: event_command.end(interupted),
            lambda: event_command.isFinished(),
            *event_command.getRequirements()
        )

    @staticmethod
    def commandFromJson(command_json: dict, load_choreo_paths: bool) -> Command:
        """
        Builds a command from the given json object

        :param command_json: the json dict to build the command from
        :param load_choreo_paths: Load path commands using choreo trajectories
        :return: a command built from the json dict
        """
        cmd_type = str(command_json['type'])
        data = command_json['data']

        if cmd_type == 'wait':
            return CommandUtil._waitCommandFromData(data)
        elif cmd_type == 'named':
            return CommandUtil._namedCommandFromData(data)
        elif cmd_type == 'path':
            return CommandUtil._pathCommandFromData(data, load_choreo_paths)
        elif cmd_type == 'sequential':
            return CommandUtil._sequentialGroupFromData(data, load_choreo_paths)
        elif cmd_type == 'parallel':
            return CommandUtil._parallelGroupFromData(data, load_choreo_paths)
        elif cmd_type == 'race':
            return CommandUtil._raceGroupFromData(data, load_choreo_paths)
        elif cmd_type == 'deadline':
            return CommandUtil._deadlineGroupFromData(data, load_choreo_paths)

        return cmd.none()

    @staticmethod
    def _waitCommandFromData(data_json: dict) -> Command:
        waitTime = float(data_json['waitTime'])
        return cmd.waitSeconds(waitTime)

    @staticmethod
    def _namedCommandFromData(data_json: dict) -> Command:
        name = str(data_json['name'])
        return NamedCommands.getCommand(name)

    @staticmethod
    def _pathCommandFromData(data_json: dict, load_choreo_paths: bool) -> Command:
        pathName = str(data_json['pathName'])

        if load_choreo_paths:
            return AutoBuilder.followPath(PathPlannerPath.fromChoreoTrajectory(pathName))
        else:
            return AutoBuilder.followPath(PathPlannerPath.fromPathFile(pathName))

    @staticmethod
    def _sequentialGroupFromData(data_json: dict, load_choreo_paths: bool) -> Command:
        commands = [CommandUtil.commandFromJson(cmd_json, load_choreo_paths) for cmd_json in data_json['commands']]
        return cmd.sequence(*commands)

    @staticmethod
    def _parallelGroupFromData(data_json: dict, load_choreo_paths: bool) -> Command:
        commands = [CommandUtil.commandFromJson(cmd_json, load_choreo_paths) for cmd_json in data_json['commands']]
        return cmd.parallel(*commands)

    @staticmethod
    def _raceGroupFromData(data_json: dict, load_choreo_paths: bool) -> Command:
        commands = [CommandUtil.commandFromJson(cmd_json, load_choreo_paths) for cmd_json in data_json['commands']]
        return cmd.race(*commands)

    @staticmethod
    def _deadlineGroupFromData(data_json: dict, load_choreo_paths: bool) -> Command:
        commands = [CommandUtil.commandFromJson(cmd_json, load_choreo_paths) for cmd_json in data_json['commands']]
        return cmd.deadline(*commands)


class AutoBuilder:
    _configured: bool = False

    _pathFollowingCommandBuilder: Callable[[PathPlannerPath], Command] = None
    _getPose: Callable[[], Pose2d] = None
    _resetPose: Callable[[Pose2d], None] = None
    _shouldFlipPath: Callable[[], bool] = None

    _pathfindingConfigured: bool = False
    _pathfindToPoseCommandBuilder: Callable[[Pose2d, PathConstraints, float, float], Command] = None
    _pathfindThenFollowPathCommandBuilder: Callable[[PathPlannerPath, PathConstraints, float], Command] = None

    @staticmethod
    def configureHolonomic(pose_supplier: Callable[[], Pose2d], reset_pose: Callable[[Pose2d], None],
                           robot_relative_speeds_supplier: Callable[[], ChassisSpeeds],
                           robot_relative_output: Callable[[ChassisSpeeds], None],
                           config: HolonomicPathFollowerConfig, should_flip_path: Callable[[], bool],
                           drive_subsystem: Subsystem) -> None:
        """
        Configures the AutoBuilder for a holonomic drivetrain.

        :param pose_supplier: a supplier for the robot's current pose
        :param reset_pose: a consumer for resetting the robot's pose
        :param robot_relative_speeds_supplier: a supplier for the robot's current robot relative chassis speeds
        :param robot_relative_output: a consumer for setting the robot's robot-relative chassis speeds
        :param config: HolonomicPathFollowerConfig for configuring the path following commands
        :param should_flip_path: Supplier that determines if paths should be flipped to the other side of the field. This will maintain a global blue alliance origin.
        :param drive_subsystem: the subsystem for the robot's drive
        """
        if AutoBuilder._configured:
            reportError('AutoBuilder has already been configured. This is likely in error.', True)

        AutoBuilder._pathFollowingCommandBuilder = lambda path: FollowPathHolonomic(
            path,
            pose_supplier,
            robot_relative_speeds_supplier,
            robot_relative_output,
            config,
            should_flip_path,
            drive_subsystem
        )
        AutoBuilder._getPose = pose_supplier
        AutoBuilder._resetPose = reset_pose
        AutoBuilder._configured = True
        AutoBuilder._shouldFlipPath = should_flip_path

        AutoBuilder._pathfindToPoseCommandBuilder = \
            lambda pose, constraints, goal_end_vel, rotation_delay_distance: PathfindHolonomic(
                constraints,
                pose_supplier,
                robot_relative_speeds_supplier,
                robot_relative_output,
                config,
                lambda: False,
                drive_subsystem,
                rotation_delay_distance=rotation_delay_distance,
                target_pose=pose,
                goal_end_vel=goal_end_vel
            )
        AutoBuilder._pathfindThenFollowPathCommandBuilder = \
            lambda path, constraints, rotation_delay_distance: PathfindThenFollowPathHolonomic(
                path,
                constraints,
                pose_supplier,
                robot_relative_speeds_supplier,
                robot_relative_output,
                config,
                should_flip_path,
                drive_subsystem,
                rotation_delay_distance=rotation_delay_distance
            )
        AutoBuilder._pathfindingConfigured = True

    @staticmethod
    def configureRamsete(pose_supplier: Callable[[], Pose2d], reset_pose: Callable[[Pose2d], None],
                         robot_relative_speeds_supplier: Callable[[], ChassisSpeeds],
                         robot_relative_output: Callable[[ChassisSpeeds], None],
                         replanning_config: ReplanningConfig, should_flip_path: Callable[[], bool],
                         drive_subsystem: Subsystem) -> None:
        """
        Configures the AutoBuilder for a differential drivetrain using a RAMSETE path follower.

        :param pose_supplier: a supplier for the robot's current pose
        :param reset_pose: a consumer for resetting the robot's pose
        :param robot_relative_speeds_supplier: a supplier for the robot's current robot relative chassis speeds
        :param robot_relative_output: a consumer for setting the robot's robot-relative chassis speeds
        :param replanning_config: Path replanning configuration
        :param should_flip_path: Supplier that determines if paths should be flipped to the other side of the field. This will maintain a global blue alliance origin.
        :param drive_subsystem: the subsystem for the robot's drive
        """
        if AutoBuilder._configured:
            reportError('AutoBuilder has already been configured. This is likely in error.', True)

        AutoBuilder._pathFollowingCommandBuilder = lambda path: FollowPathRamsete(
            path,
            pose_supplier,
            robot_relative_speeds_supplier,
            robot_relative_output,
            replanning_config,
            should_flip_path,
            drive_subsystem
        )
        AutoBuilder._getPose = pose_supplier
        AutoBuilder._resetPose = reset_pose
        AutoBuilder._configured = True
        AutoBuilder._shouldFlipPath = should_flip_path

        AutoBuilder._pathfindToPoseCommandBuilder = \
            lambda pose, constraints, goal_end_vel, rotation_delay_distance: PathfindRamsete(
                constraints,
                pose_supplier,
                robot_relative_speeds_supplier,
                robot_relative_output,
                replanning_config,
                lambda: False,
                drive_subsystem,
                target_position=pose.translation(),
                goal_end_vel=goal_end_vel
            )
        AutoBuilder._pathfindThenFollowPathCommandBuilder = \
            lambda path, constraints, rotation_delay_distance: PathfindThenFollowPathRamsete(
                path,
                constraints,
                pose_supplier,
                robot_relative_speeds_supplier,
                robot_relative_output,
                replanning_config,
                should_flip_path,
                drive_subsystem
            )
        AutoBuilder._pathfindingConfigured = True

    @staticmethod
    def configureLTV(pose_supplier: Callable[[], Pose2d], reset_pose: Callable[[Pose2d], None],
                     robot_relative_speeds_supplier: Callable[[], ChassisSpeeds],
                     robot_relative_output: Callable[[ChassisSpeeds], None],
                     qelems: Tuple[float, float, float], relems: Tuple[float, float], dt: float,
                     replanning_config: ReplanningConfig, should_flip_path: Callable[[], bool],
                     drive_subsystem: Subsystem) -> None:
        """
        Configures the AutoBuilder for a differential drivetrain using a LTVUnicycleController path follower.

        :param pose_supplier: a supplier for the robot's current pose
        :param reset_pose: a consumer for resetting the robot's pose
        :param robot_relative_speeds_supplier: a supplier for the robot's current robot relative chassis speeds
        :param robot_relative_output: a consumer for setting the robot's robot-relative chassis speeds
        :param qelems: The maximum desired error tolerance for each state
        :param relems: The maximum desired control effort for each input
        :param dt: The amount of time between each robot control loop, default is 0.02s
        :param replanning_config: Path replanning configuration
        :param should_flip_path: Supplier that determines if paths should be flipped to the other side of the field. This will maintain a global blue alliance origin.
        :param drive_subsystem: the subsystem for the robot's drive
        """
        if AutoBuilder._configured:
            reportError('AutoBuilder has already been configured. This is likely in error.', True)

        AutoBuilder._pathFollowingCommandBuilder = lambda path: FollowPathLTV(
            path,
            pose_supplier,
            robot_relative_speeds_supplier,
            robot_relative_output,
            qelems, relems, dt,
            replanning_config,
            should_flip_path,
            drive_subsystem
        )
        AutoBuilder._getPose = pose_supplier
        AutoBuilder._resetPose = reset_pose
        AutoBuilder._configured = True
        AutoBuilder._shouldFlipPath = should_flip_path

        AutoBuilder._pathfindToPoseCommandBuilder = \
            lambda pose, constraints, goal_end_vel, rotation_delay_distance: PathfindLTV(
                constraints,
                pose_supplier,
                robot_relative_speeds_supplier,
                robot_relative_output,
                qelems, relems, dt,
                replanning_config,
                lambda: False,
                drive_subsystem,
                target_position=pose.translation(),
                goal_end_vel=goal_end_vel
            )
        AutoBuilder._pathfindThenFollowPathCommandBuilder = \
            lambda path, constraints, rotation_delay_distance: PathfindThenFollowPathLTV(
                path,
                constraints,
                pose_supplier,
                robot_relative_speeds_supplier,
                robot_relative_output,
                qelems, relems, dt,
                replanning_config,
                should_flip_path,
                drive_subsystem
            )
        AutoBuilder._pathfindingConfigured = True

    @staticmethod
    def configureCustom(path_following_command_builder: Callable[[PathPlannerPath], Command],
                        pose_supplier: Callable[[], Pose2d], reset_pose: Callable[[Pose2d], None]) -> None:
        """
        Configures the AutoBuilder with custom path following command builder. Building pathfinding commands is not supported if using a custom command builder.

        :param path_following_command_builder: a function that builds a command to follow a given path
        :param pose_supplier: a supplier for the robot's current pose
        :param reset_pose: a consumer for resetting the robot's pose
        """
        if AutoBuilder._configured:
            reportError('AutoBuilder has already been configured. This is likely in error.', True)

        AutoBuilder._pathFollowingCommandBuilder = path_following_command_builder
        AutoBuilder._getPose = pose_supplier
        AutoBuilder._resetPose = reset_pose
        AutoBuilder._configured = True
        AutoBuilder._shouldFlipPath = lambda: False

        AutoBuilder._pathfindingConfigured = False

    @staticmethod
    def isConfigured() -> bool:
        """
        Returns whether the AutoBuilder has been configured.

        :return: true if the AutoBuilder has been configured, false otherwise
        """
        return AutoBuilder._configured

    @staticmethod
    def isPathfindingConfigured() -> bool:
        """
        Returns whether the AutoBuilder has been configured for pathfinding.

        :return: true if the AutoBuilder has been configured for pathfinding, false otherwise
        """
        return AutoBuilder._pathfindingConfigured

    @staticmethod
    def followPath(path: PathPlannerPath) -> Command:
        """
        Builds a command to follow a path with event markers.

        :param path: the path to follow
        :return: a path following command with events for the given path
        """
        if not AutoBuilder.isConfigured():
            raise RuntimeError('Auto builder was used to build a path following command before being configured')

        return AutoBuilder._pathFollowingCommandBuilder(path)

    @staticmethod
    def pathfindToPose(pose: Pose2d, constraints: PathConstraints, goal_end_vel: float = 0.0,
                       rotation_delay_distance: float = 0.0) -> Command:
        """
        Build a command to pathfind to a given pose. If not using a holonomic drivetrain, the pose rotation and rotation delay distance will have no effect.

        :param pose: The pose to pathfind to
        :param constraints: The constraints to use while pathfinding
        :param goal_end_vel: The goal end velocity of the robot when reaching the target pose
        :param rotation_delay_distance: The distance the robot should move from the start position before attempting to rotate to the final rotation
        :return: A command to pathfind to a given pose
        """
        if not AutoBuilder.isPathfindingConfigured():
            raise RuntimeError('Auto builder was used to build a pathfinding command before being configured')

        return AutoBuilder._pathfindToPoseCommandBuilder(pose, constraints, goal_end_vel, rotation_delay_distance)

    @staticmethod
    def pathfindThenFollowPath(goal_path: PathPlannerPath, pathfinding_constraints: PathConstraints,
                               rotation_delay_distance: float = 0.0) -> Command:
        """
        Build a command to pathfind to a given path, then follow that path. If not using a holonomic drivetrain, the pose rotation delay distance will have no effect.

        :param goal_path: The path to pathfind to, then follow
        :param pathfinding_constraints: The constraints to use while pathfinding
        :param rotation_delay_distance: The distance the robot should move from the start position before attempting to rotate to the final rotation
        :return: A command to pathfind to a given path, then follow the path
        """
        if not AutoBuilder.isPathfindingConfigured():
            raise RuntimeError('Auto builder was used to build a pathfinding command before being configured')

        return AutoBuilder._pathfindThenFollowPathCommandBuilder(goal_path, pathfinding_constraints,
                                                                 rotation_delay_distance)

    @staticmethod
    def getStartingPoseFromJson(starting_pose_json: dict) -> Pose2d:
        """
        Get the starting pose from its JSON representation. This is only used internally.

        :param starting_pose_json: JSON dict representing a starting pose.
        :return: The Pose2d starting pose
        """
        pos = starting_pose_json['position']
        x = float(pos['x'])
        y = float(pos['y'])
        deg = float(starting_pose_json['rotation'])

        return Pose2d(x, y, Rotation2d.fromDegrees(deg))

    @staticmethod
    def getAutoCommandFromJson(auto_json: dict) -> Command:
        """
        Builds an auto command from the given JSON dict.

        :param auto_json: the JSON dict to build the command from
        :return: an auto command built from the JSON object
        """
        commandJson = auto_json['command']
        choreoAuto = 'choreoAuto' in auto_json and bool(auto_json['choreoAuto'])

        autoCommand = CommandUtil.commandFromJson(commandJson, choreoAuto)
        if auto_json['startingPose'] is not None:
            startPose = AutoBuilder.getStartingPoseFromJson(auto_json['startingPose'])
            return cmd.sequence(cmd.runOnce(lambda: AutoBuilder._resetPose(
                flipFieldPose(startPose) if AutoBuilder._shouldFlipPath() else startPose)), autoCommand)
        else:
            return autoCommand

    @staticmethod
    def buildAuto(auto_name: str) -> Command:
        """
        Builds an auto command for the given auto name.

        :param auto_name: the name of the auto to build
        :return: an auto command for the given auto name
        """
        filePath = os.path.join(getDeployDirectory(), 'pathplanner', 'autos', auto_name + '.auto')

        with open(filePath, 'r') as f:
            auto_json = json.loads(f.read())
            return AutoBuilder.getAutoCommandFromJson(auto_json)


class PathPlannerAuto(Command):
    _autoCommand: Command

    _instances: int = 0

    def __init__(self, auto_name: str):
        """
        Constructs a new PathPlannerAuto command.

        :param auto_name: the name of the autonomous routine to load and run
        """
        super().__init__()

        if not AutoBuilder.isConfigured():
            raise RuntimeError('AutoBuilder was not configured before attempting to load a PathPlannerAuto from file')

        self._autoCommand = AutoBuilder.buildAuto(auto_name)
        self.addRequirements(*self._autoCommand.getRequirements())
        self.setName(auto_name)

        PathPlannerAuto._instances += 1
        report(tResourceType.kResourceType_PathPlannerAuto.value, PathPlannerAuto._instances)

    @staticmethod
    def getStartingPoseFromAutoFile(auto_name: str) -> Pose2d:
        """
        Get the starting pose from the given auto file

        :param auto_name: Name of the auto to get the pose from
        :return: Starting pose from the given auto
        """
        filePath = os.path.join(getDeployDirectory(), 'pathplanner', 'autos', auto_name + '.auto')

        with open(filePath, 'r') as f:
            auto_json = json.loads(f.read())
            return AutoBuilder.getStartingPoseFromJson(auto_json['startingPose'])

    @staticmethod
    def _pathsFromCommandJson(command_json: dict, choreo_paths: bool) -> List[PathPlannerPath]:
        paths = []

        cmdType = str(command_json['type'])
        data = command_json['data']

        if cmdType == 'path':
            pathName = str(data['pathName'])
            if choreo_paths:
                paths.append(PathPlannerPath.fromChoreoTrajectory(pathName))
            else:
                paths.append(PathPlannerPath.fromPathFile(pathName))
        elif cmdType == 'sequential' or cmdType == 'parallel' or cmdType == 'race' or cmdType == 'deadline':
            for cmdJson in data['commands']:
                paths.extend(PathPlannerAuto._pathsFromCommandJson(cmdJson, choreo_paths))
        return paths

    @staticmethod
    def getPathGroupFromAutoFile(auto_name: str) -> List[PathPlannerPath]:
        """
        Get a list of every path in the given auto (depth first)

        :param auto_name: Name of the auto to get the path group from
        :return: List of paths in the auto
        """
        filePath = os.path.join(getDeployDirectory(), 'pathplanner', 'autos', auto_name + '.auto')

        with open(filePath, 'r') as f:
            auto_json = json.loads(f.read())
            choreoAuto = 'choreoAuto' in auto_json and bool(auto_json['choreoAuto'])

            return PathPlannerAuto._pathsFromCommandJson(auto_json['command'], choreoAuto)

    def initialize(self):
        self._autoCommand.initialize()

    def execute(self):
        self._autoCommand.execute()

    def isFinished(self) -> bool:
        return self._autoCommand.isFinished()

    def end(self, interrupted: bool):
        self._autoCommand.end(interrupted)
