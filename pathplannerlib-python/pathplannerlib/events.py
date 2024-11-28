from typing import List, TYPE_CHECKING, Callable
from commands2 import Command, Subsystem, CommandScheduler, cmd
from commands2.button import Trigger
from wpilib.event import EventLoop

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

    def setTimestamp(self, timestamp: float):
        self._timestamp = timestamp

    def handleEvent(self, eventScheduler: 'EventScheduler') -> None:
        raise NotImplementedError

    def cancelEvent(self, eventScheduler: 'EventScheduler') -> None:
        raise NotImplementedError

    def copyWithTime(self, timestamp: float) -> 'Event':
        raise NotImplementedError


class EventScheduler:
    _eventCommands: dict
    _upcomingEvents: List[Event]

    _eventLoop: EventLoop = EventLoop()

    def __init__(self):
        """
        Create a new EventScheduler
        """
        self._eventCommands = {}
        self._upcomingEvents = []

    def initialize(self, trajectory: 'PathPlannerTrajectory') -> None:
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

            command.execute()

            if command.isFinished():
                command.end(False)
                self._eventCommands[command] = False

        EventScheduler._eventLoop.poll()

    def end(self) -> None:
        """
        End commands currently being run by this scheduler. This should be called from the end method of
        the command running this scheduler.
        """
        # Cancel all currently running commands
        for command in self._eventCommands:
            if self._eventCommands[command]:
                command.end(True)

        # Cancel any unhandled events
        for event in self._upcomingEvents:
            event.cancelEvent(self)

        self._eventCommands.clear()
        self._upcomingEvents.clear()

    @staticmethod
    def getSchedulerRequirements(path: 'PathPlannerPath') -> set[Subsystem]:
        """
        Get the event requirements for the given path

        :param path: The path to get all requirements for
        :return: Set of event requirements for the given path
        """
        allReqs = set()

        for m in path.getEventMarkers():
            if m.command is not None:
                allReqs.update(m.command.getRequirements())

        return allReqs

    @staticmethod
    def getEventLoop() -> EventLoop:
        return EventScheduler._eventLoop

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


class EventTrigger(Trigger):
    _eventConditions: dict[str, bool] = {}

    def __init__(self, name: str, eventLoop: EventLoop = None):
        super().__init__(eventLoop if eventLoop is not None else EventScheduler.getEventLoop(),
                         EventTrigger.pollCondition(name))

    @staticmethod
    def setCondition(name: str, value: bool) -> None:
        EventTrigger._eventConditions[name] = value

    @staticmethod
    def pollCondition(name: str) -> Callable[[], bool]:
        # Ensure there is a condition in the map for this name
        if name not in EventTrigger._eventConditions:
            EventTrigger.setCondition(name, False)

        return lambda: EventTrigger._eventConditions[name]


class PointTowardsZoneTrigger(Trigger):
    _zoneConditions: dict[str, bool] = {}

    def __init__(self, name: str, eventLoop: EventLoop = None):
        super().__init__(eventLoop if eventLoop is not None else EventScheduler.getEventLoop(),
                         PointTowardsZoneTrigger.pollCondition(name))

    @staticmethod
    def setWithinZone(name: str, withinZone: bool) -> None:
        PointTowardsZoneTrigger._zoneConditions[name] = withinZone

    @staticmethod
    def pollCondition(name: str) -> Callable[[], bool]:
        # Ensure there is a condition in the map for this name
        if name not in PointTowardsZoneTrigger._zoneConditions:
            PointTowardsZoneTrigger.setWithinZone(name, False)

        return lambda: PointTowardsZoneTrigger._zoneConditions[name]


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

    def handleEvent(self, eventScheduler: 'EventScheduler') -> None:
        eventScheduler.scheduleCommand(self._command)

    def cancelEvent(self, eventScheduler: 'EventScheduler') -> None:
        # Do nothing
        pass

    def copyWithTime(self, timestamp: float) -> Event:
        return ScheduleCommandEvent(timestamp, self._command)


class CancelCommandEvent(Event):
    _command: Command

    def __init__(self, timestamp: float, command: Command):
        """
        Create an event to cancel a command

        :param timestamp: The trajectory timestamp for this event
        :param command: The command to cancel
        """
        super().__init__(timestamp)
        self._command = command

    def handleEvent(self, eventScheduler: 'EventScheduler') -> None:
        eventScheduler.cancelCommand(self._command)

    def cancelEvent(self, eventScheduler: 'EventScheduler') -> None:
        # Do nothing
        pass

    def copyWithTime(self, timestamp: float) -> Event:
        return CancelCommandEvent(timestamp, self._command)


class TriggerEvent(Event):
    _name: str
    _active: bool

    def __init__(self, timestamp: float, name: str, active: bool):
        """
        Create an event to control an event trigger

        :param timestamp: The trajectory timestamp for this event
        :param name: The name of the trigger to control
        :param active: Should the trigger be activated by this event
        """
        super().__init__(timestamp)
        self._name = name
        self._active = active

    def handleEvent(self, eventScheduler: 'EventScheduler') -> None:
        EventTrigger.setCondition(self._name, self._active)

    def cancelEvent(self, eventScheduler: 'EventScheduler') -> None:
        if not self._active:
            EventTrigger.setCondition(self._name, False)

    def copyWithTime(self, timestamp: float) -> Event:
        return TriggerEvent(timestamp, self._name, self._active)


class PointTowardsZoneEvent(Event):
    _name: str
    _active: bool

    def __init__(self, timestamp: float, name: str, active: bool):
        """
        Create an event to control a point towards zone trigger

        :param timestamp: The trajectory timestamp for this event
        :param name: The name of the zone
        :param active: Should the trigger be activated by this event
        """
        super().__init__(timestamp)
        self._name = name
        self._active = active

    def handleEvent(self, eventScheduler: 'EventScheduler') -> None:
        PointTowardsZoneTrigger.setWithinZone(self._name, self._active)

    def cancelEvent(self, eventScheduler: 'EventScheduler') -> None:
        if not self._active:
            PointTowardsZoneTrigger.setWithinZone(self._name, False)

    def copyWithTime(self, timestamp: float) -> Event:
        return PointTowardsZoneEvent(timestamp, self._name, self._active)


class OneShotTriggerEvent(Event):
    _name: str
    _resetCommand: Command

    def __init__(self, timestamp: float, name: str):
        """
        Create an event for activating a trigger, then deactivating it the next loop

        :param timestamp: The trajectory timestamp for this event
        :param name: The name of the trigger to control
        """
        super().__init__(timestamp)
        self._name = name
        self._resetCommand = cmd.waitSeconds(0).andThen(
            cmd.runOnce(lambda: EventTrigger.setCondition(self._name, False))).ignoringDisable(True)

    def handleEvent(self, eventScheduler: 'EventScheduler') -> None:
        EventTrigger.setCondition(self._name, True)
        # We schedule this command with the main command scheduler so that it is guaranteed to be run
        # in its entirety, since the EventScheduler could cancel this command before it finishes
        CommandScheduler.getInstance().schedule(self._resetCommand)

    def cancelEvent(self, eventScheduler: 'EventScheduler') -> None:
        # Do nothing
        pass

    def copyWithTime(self, timestamp: float) -> Event:
        return OneShotTriggerEvent(timestamp, self._name)
