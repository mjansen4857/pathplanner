from commands2.command import Command
from commands2.functionalcommand import FunctionalCommand
import commands2.cmd as cmd
from path import PathPlannerPath

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
            lambda: event_command.isFinished(),
            lambda interupted: event_command.end(interupted),
            *event_command.getRequirements()
        )

    @staticmethod
    def commandFromJson(command_json: dict) -> Command:
        """
        Builds a command from the given json object

        :param command_json: the json dict to build the command from
        :return: a command built from the json dict
        """
        cmd_type = str(command_json['type'])
        data = command_json['data']

        if cmd_type == 'wait':
            return CommandUtil._waitCommandFromData(data)
        elif cmd_type == 'named':
            return CommandUtil._namedCommandFromData(data)
        elif cmd_type == 'path':
            return CommandUtil._pathCommandFromData(data)
        elif cmd_type == 'sequential':
            return CommandUtil._sequentialGroupFromData(data)
        elif cmd_type == 'parallel':
            return CommandUtil._parallelGroupFromData(data)
        elif cmd_type == 'race':
            return CommandUtil._raceGroupFromData(data)
        elif cmd_type == 'deadline':
            return CommandUtil._deadlineGroupFromData(data)

        return cmd.none()

    @staticmethod
    def _waitCommandFromData(data_json: dict) -> Command:
        waitTime = float(data_json['waitTime'])
        return cmd.waitSeconds(waitTime)

    @staticmethod
    def _namedCommandFromData(data_json: dict) -> Command:
        name = str(data_json['name'])
        return cmd.none() # TODO

    @staticmethod
    def _pathCommandFromData(data_json: dict) -> Command:
        pathName = str(data_json['pathName'])
        path = PathPlannerPath.fromPathFile(pathName)
        return cmd.none() # TODO

    @staticmethod
    def _sequentialGroupFromData(data_json: dict) -> Command:
        commands = [CommandUtil.commandFromJson(cmd_json) for cmd_json in data_json['commands']]
        return cmd.sequence(*commands)

    @staticmethod
    def _parallelGroupFromData(data_json: dict) -> Command:
        commands = [CommandUtil.commandFromJson(cmd_json) for cmd_json in data_json['commands']]
        return cmd.parallel(*commands)

    @staticmethod
    def _raceGroupFromData(data_json: dict) -> Command:
        commands = [CommandUtil.commandFromJson(cmd_json) for cmd_json in data_json['commands']]
        return cmd.race(*commands)

    @staticmethod
    def _deadlineGroupFromData(data_json: dict) -> Command:
        commands = [CommandUtil.commandFromJson(cmd_json) for cmd_json in data_json['commands']]
        return cmd.deadline(*commands)
