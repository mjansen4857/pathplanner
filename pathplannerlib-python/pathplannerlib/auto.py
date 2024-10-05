from commands2.functionalcommand import FunctionalCommand
import commands2.cmd as cmd
from .path import PathPlannerPath, PathConstraints
from typing import Callable, List
from wpimath.geometry import Pose2d
from wpimath.kinematics import ChassisSpeeds
from .commands import FollowPathCommand, PathfindingCommand, PathfindThenFollowPath
from .util import FlippingUtil, DriveFeedforward
from .controller import PathFollowingController
import os
from wpilib import getDeployDirectory, reportError, reportWarning, SendableChooser
import json
from commands2.command import Command
from commands2.subsystem import Subsystem
from .config import RobotConfig
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
            reportWarning(
                f"PathPlanner attempted to create a command '{name}' that has not been registered with NamedCommands.registerCommand",
                False)
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
    _isHolonomic: bool = False

    _pathfindingConfigured: bool = False
    _pathfindToPoseCommandBuilder: Callable[[Pose2d, PathConstraints, float], Command] = None
    _pathfindThenFollowPathCommandBuilder: Callable[[PathPlannerPath, PathConstraints], Command] = None

    @staticmethod
    def configure(pose_supplier: Callable[[], Pose2d], reset_pose: Callable[[Pose2d], None],
                  robot_relative_speeds_supplier: Callable[[], ChassisSpeeds],
                  output: Callable[[ChassisSpeeds, List[DriveFeedforward]], None],
                  controller: PathFollowingController,
                  robot_config: RobotConfig,
                  should_flip_path: Callable[[], bool],
                  drive_subsystem: Subsystem) -> None:
        """
        Configures the AutoBuilder for using PathPlanner's built-in commands.

        :param pose_supplier: a supplier for the robot's current pose
        :param reset_pose: a consumer for resetting the robot's pose
        :param robot_relative_speeds_supplier: a supplier for the robot's current robot relative chassis speeds
        :param output: Output function that accepts robot-relative ChassisSpeeds and feedforwards for
            each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
            using a differential drive, they will be in L, R order.
            <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
            module states, you will need to reverse the feedforwards for modules that have been flipped
        :param controller Path following controller that will be used to follow paths
        :param robot_config The robot configuration
        :param should_flip_path: Supplier that determines if paths should be flipped to the other side of the field. This will maintain a global blue alliance origin.
        :param drive_subsystem: the subsystem for the robot's drive
        """
        if AutoBuilder._configured:
            reportError('AutoBuilder has already been configured. This is likely in error.', True)

        AutoBuilder._pathFollowingCommandBuilder = lambda path: FollowPathCommand(
            path,
            pose_supplier,
            robot_relative_speeds_supplier,
            output,
            controller,
            robot_config,
            should_flip_path,
            drive_subsystem
        )
        AutoBuilder._getPose = pose_supplier
        AutoBuilder._resetPose = reset_pose
        AutoBuilder._configured = True
        AutoBuilder._shouldFlipPath = should_flip_path
        AutoBuilder._isHolonomic = robot_config.isHolonomic

        AutoBuilder._pathfindToPoseCommandBuilder = \
            lambda pose, constraints, goal_end_vel: PathfindingCommand(
                constraints,
                pose_supplier,
                robot_relative_speeds_supplier,
                output,
                controller,
                robot_config,
                lambda: False,
                drive_subsystem,
                target_pose=pose,
                goal_end_vel=goal_end_vel
            )
        AutoBuilder._pathfindThenFollowPathCommandBuilder = \
            lambda path, constraints: PathfindThenFollowPath(
                path,
                constraints,
                pose_supplier,
                robot_relative_speeds_supplier,
                output,
                controller,
                robot_config,
                should_flip_path,
                drive_subsystem
            )
        AutoBuilder._pathfindingConfigured = True

    @staticmethod
    def configureCustom(path_following_command_builder: Callable[[PathPlannerPath], Command],
                        reset_pose: Callable[[Pose2d], None],
                        isHolonomic: bool,
                        should_flip_pose: Callable[[], bool] = lambda: False) -> None:
        """
        Configures the AutoBuilder with custom path following command builder. Building pathfinding commands is not supported if using a custom command builder.

        :param path_following_command_builder: a function that builds a command to follow a given path
        :param reset_pose: a consumer for resetting the robot's pose
        :param isHolonomic Does the robot have a holonomic drivetrain
        :param should_flip_pose: Supplier that determines if the starting pose should be flipped to the other side of the field. This will maintain a global blue alliance origin. NOTE: paths will not be flipped when configured with a custom path following command. Flipping the paths must be handled in your command.
        """
        if AutoBuilder._configured:
            reportError('AutoBuilder has already been configured. This is likely in error.', True)

        AutoBuilder._pathFollowingCommandBuilder = path_following_command_builder
        AutoBuilder._resetPose = reset_pose
        AutoBuilder._configured = True
        AutoBuilder._shouldFlipPath = should_flip_pose
        AutoBuilder._isHolonomic = isHolonomic

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
    def isHolonomic() -> bool:
        """
        Get if AutoBuilder was configured for a holonomic drive train

        :return: True if holonomic
        """
        return AutoBuilder._isHolonomic

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
    def pathfindToPose(pose: Pose2d, constraints: PathConstraints, goal_end_vel: float = 0.0) -> Command:
        """
        Build a command to pathfind to a given pose. If not using a holonomic drivetrain, the pose rotation and
        rotation delay distance will have no effect.

        :param pose: The pose to pathfind to
        :param constraints: The constraints to use while pathfinding
        :param goal_end_vel: The goal end velocity of the robot when reaching the target pose
        :return: A command to pathfind to a given pose
        """
        if not AutoBuilder.isPathfindingConfigured():
            raise RuntimeError('Auto builder was used to build a pathfinding command before being configured')

        return AutoBuilder._pathfindToPoseCommandBuilder(pose, constraints, goal_end_vel)

    @staticmethod
    def pathfindToPoseFlipped(pose: Pose2d, constraints: PathConstraints, goal_end_vel: float = 0.0) -> Command:
        """
        Build a command to pathfind to a given pose that will be flipped based on the value of the path flipping
        supplier when this command is run. If not using a holonomic drivetrain, the pose rotation and rotation delay
        distance will have no effect.

        :param pose: The pose to pathfind to. This will be flipped if the path flipping supplier returns true
        :param constraints: The constraints to use while pathfinding
        :param goal_end_vel: The goal end velocity of the robot when reaching the target pose
        :return: A command to pathfind to a given pose
        """
        return cmd.either(
            AutoBuilder.pathfindToPose(FlippingUtil.flipFieldPose(pose), constraints, goal_end_vel),
            AutoBuilder.pathfindToPose(pose, constraints, goal_end_vel),
            AutoBuilder._shouldFlipPath
        )

    @staticmethod
    def pathfindThenFollowPath(goal_path: PathPlannerPath, pathfinding_constraints: PathConstraints) -> Command:
        """
        Build a command to pathfind to a given path, then follow that path. If not using a holonomic drivetrain, the pose rotation delay distance will have no effect.

        :param goal_path: The path to pathfind to, then follow
        :param pathfinding_constraints: The constraints to use while pathfinding
        :return: A command to pathfind to a given path, then follow the path
        """
        if not AutoBuilder.isPathfindingConfigured():
            raise RuntimeError('Auto builder was used to build a pathfinding command before being configured')

        return AutoBuilder._pathfindThenFollowPathCommandBuilder(goal_path, pathfinding_constraints)

    @staticmethod
    def resetOdom(bluePose: Pose2d) -> Command:
        """
        Create a command to reset the robot's odometry to a given blue alliance pose

        :param bluePose: The pose to reset to, relative to blue alliance origin
        :return: Command to reset the robot's odometry
        """
        return cmd.runOnce(lambda: AutoBuilder._resetPose(
            FlippingUtil.flipFieldPose(bluePose) if AutoBuilder._shouldFlipPath() else bluePose))

    @staticmethod
    def buildAuto(auto_name: str) -> Command:
        """
        Builds an auto command for the given auto name.

        :param auto_name: the name of the auto to build
        :return: an auto command for the given auto name
        """
        return PathPlannerAuto(auto_name)

    @staticmethod
    def buildAutoChooser(default_auto_name: str = "") -> SendableChooser:
        """
        Create and populate a sendable chooser with all PathPlannerAutos in the project and the default auto name selected.
        
        :param default_auto_name: the name of the default auto to be selected in the chooser
        :return: a sendable chooser object populated with all of PathPlannerAutos in the project
        """
        if not AutoBuilder.isConfigured():
            raise RuntimeError('AutoBuilder was not configured before attempting to build an auto chooser')
        auto_folder_path = os.path.join(getDeployDirectory(), 'pathplanner', 'autos')
        auto_list = os.listdir(auto_folder_path)

        chooser = SendableChooser()
        default_auto_added = False

        for auto in auto_list:
            auto = auto.removesuffix(".auto")
            if auto == default_auto_name:
                default_auto_added = True
                chooser.setDefaultOption(auto, AutoBuilder.buildAuto(auto))
            else:
                chooser.addOption(auto, AutoBuilder.buildAuto(auto))
        if not default_auto_added:
            chooser.setDefaultOption("None", cmd.none())
        return chooser


class PathPlannerAuto(Command):
    _autoCommand: Command
    _startingPose: Pose2d

    _instances: int = 0

    def __init__(self, auto_name: str):
        """
        Constructs a new PathPlannerAuto command.

        :param auto_name: the name of the autonomous routine to load and run
        """
        super().__init__()

        if not AutoBuilder.isConfigured():
            raise RuntimeError('AutoBuilder was not configured before attempting to load a PathPlannerAuto from file')

        filePath = os.path.join(getDeployDirectory(), 'pathplanner', 'autos', auto_name + '.auto')

        with open(filePath, 'r') as f:
            auto_json = json.loads(f.read())
            self._initFromJson(auto_json)

        self.addRequirements(*self._autoCommand.getRequirements())
        self.setName(auto_name)

        PathPlannerAuto._instances += 1
        report(tResourceType.kResourceType_PathPlannerAuto.value, PathPlannerAuto._instances)

    def _initFromJson(self, auto_json: dict):
        commandJson = auto_json['command']
        choreoAuto = 'choreoAuto' in auto_json and bool(auto_json['choreoAuto'])
        command = CommandUtil.commandFromJson(commandJson, choreoAuto)
        resetOdom = 'resetOdom' in auto_json and bool(auto_json['resetOdom'])
        pathsInAuto = PathPlannerAuto._pathsFromCommandJson(commandJson, choreoAuto)
        if len(pathsInAuto) > 0:
            if AutoBuilder.isHolonomic():
                self._startingPose = Pose2d(pathsInAuto[0].getPoint(0).position,
                                            pathsInAuto[0].getIdealStartingState().rotation)
            else:
                self._startingPose = pathsInAuto[0].getStartingDifferentialPose()
        else:
            self._startingPose = Pose2d()

        if resetOdom:
            self._autoCommand = cmd.sequence(AutoBuilder.resetOdom(self._startingPose), command)
        else:
            self._autoCommand = command

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
