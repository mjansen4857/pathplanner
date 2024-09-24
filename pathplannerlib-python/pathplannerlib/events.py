from typing import List, TYPE_CHECKING, override
from commands2 import Command, Subsystem

if TYPE_CHECKING:
    from .trajectory import PathPlannerTrajectory
    from .path import PathPlannerPath


class Event:
    _timestamp: float

    def __init__(self, timestamp: float):
        """
        Create a new event

        :param timestamp: The trajectory timestamp this event should be handled at
        """
        self._timestamp = timestamp

    def getTimestamp(self) -> float:
        return self._timestamp

    def handleEvent(self, eventScheduler: 'EventScheduler') -> None:
        raise NotImplementedError


class ScheduleCommandEvent(Event):
    _command: Command

    def __init__(self, timestamp: float, command: Command):
        """
        Create an event to schedule a command

        :param timestamp: The trajectory timestamp for this event
        :param command: The command to schedule
        """
        super().__init__(timestamp)
        self._command = command

    @override
    def handleEvent(self, eventScheduler: 'EventScheduler') -> None:
        eventScheduler.scheduleCommand(self._command)


class EventScheduler:
    _eventCommands: dict
    _upcomingEvents: List[Event]

    def __init__(self):
        """
        Create a new EventScheduler
        """
        self._eventCommands = {}
        self._upcomingEvents = []

    def initialize(self, trajectory: PathPlannerTrajectory) -> None:
        """
        Initialize the EventScheduler for the given trajectory. This should be called from the initialize
        method of the command running this scheduler.

        :param trajectory: The trajectory this scheduler should handle events for
        """
        self._eventCommands.clear()
        self._upcomingEvents.clear()

        self._upcomingEvents = [e for e in trajectory.getEvents()]

    def execute(self, time: float) -> None:
        """
        Run the scheduler. This should be called from the execute method of the command running this scheduler.

        :param time: The current time along the trajectory
        """
        # Check for events that should be handled this loop
        while len(self._upcomingEvents) > 0 and time >= self._upcomingEvents[0].getTimestamp():
            self._upcomingEvents.pop(0).handleEvent(self)

        # Run currently running commands
        for command in self._eventCommands:
            if not self._eventCommands[command]:
                continue

            command.execute(self)

            if command.isFinished():
                command.end(False)
                self._eventCommands[command] = False

    def end(self) -> None:
        """
        End commands currently being run by this scheduler. This should be called from the end method of
        the command running this scheduler.
        """
        # Cancel all currently running commands
        for command in self._eventCommands:
            if self._eventCommands[command]:
                command.end(True)

        self._eventCommands.clear()
        self._upcomingEvents.clear()

    @staticmethod
    def getSchedulerRequirements(path: PathPlannerPath) -> set[Subsystem]:
        """
        Get the event requirements for the given path

        :param path: The path to get all requirements for
        :return: Set of event requirements for the given path
        """
        allReqs = set()

        for m in path.getEventMarkers():
            allReqs.update(m.command.getRequirements())

        return allReqs

    def scheduleCommand(self, command: Command) -> None:
        """
        Schedule a command on this scheduler. This will cancel other commands that share requirements
        with the given command. Do not call this.

        :param command: The command to schedule
        """
        # Check for commands that should be cancelled by this command
        for cmd in self._eventCommands:
            if not self._eventCommands[cmd]:
                continue

            for req in command.getRequirements():
                if req in cmd.getRequirements():
                    self.cancelCommand(cmd)

        command.initialize()
        self._eventCommands[command] = True

    def cancelCommand(self, command: Command) -> None:
        """
        Cancel a command on this scheduler. Do not call this.

        :param command: The command to cancel
        """
        if command not in self._eventCommands or not self._eventCommands[command]:
            # Command is not currently running
            return

        command.end(True)
        self._eventCommands[command] = False
