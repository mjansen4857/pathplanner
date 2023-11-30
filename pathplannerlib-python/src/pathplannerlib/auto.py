from commands2.command import Command
from commands2.functionalcommand import FunctionalCommand
import commands2.cmd

class CommandUtil:
    @staticmethod
    def wrappedEventCommand(event_command: Command) -> Command:
        return FunctionalCommand(
            lambda: event_command.initialize(),
            lambda: event_command.execute(),
            lambda: event_command.isFinished(),
            lambda interupted: event_command.end(interupted),
            *event_command.getRequirements()
        )
