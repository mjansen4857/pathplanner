package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import edu.wpi.first.wpilibj2.command.*;
import java.util.*;

public abstract class BaseAutoBuilder {
  protected final HashMap<String, Command> eventMap;

  protected BaseAutoBuilder(HashMap<String, Command> eventMap) {
    this.eventMap = eventMap;
  }

  protected abstract CommandBase getPathFollowingCommand(PathPlannerTrajectory trajectory);

  public CommandBase followPathWithEvents(PathPlannerTrajectory trajectory) {
    return new ParallelDeadlineGroup(getPathFollowingCommand(trajectory), eventGroup(trajectory));
  }

  protected ParallelCommandGroup eventGroup(PathPlannerTrajectory trajectory) {
    Set<WrappedEventCommand> prevEventCommands = new HashSet<>();
    ParallelCommandGroup eventGroup = new ParallelCommandGroup();

    for (PathPlannerTrajectory.EventMarker marker : trajectory.getMarkers()) {
      for (String name : marker.names) {
        if (eventMap.containsKey(name)) {
          Command cmd = eventMap.get(name);
          Set<WrappedEventCommand> commandsToCancel = new HashSet<>();

          for (WrappedEventCommand prevCommand : prevEventCommands) {
            if (!Collections.disjoint(cmd.getRequirements(), prevCommand.getSoftRequirements())) {
              commandsToCancel.add(prevCommand);
            }
          }

          WrappedEventCommand eventCommand = new WrappedEventCommand(cmd);

          eventGroup.addCommands(
              new SequentialCommandGroup(
                  new WaitCommand(marker.timeSeconds),
                  new InstantCommand(
                      () -> {
                        for (WrappedEventCommand c : commandsToCancel) {
                          c.cancel();
                        }
                      }),
                  eventCommand));
          eventGroup.addRequirements(cmd.getRequirements().toArray(new Subsystem[0]));
          prevEventCommands.add(eventCommand);
        }
      }
    }
    return eventGroup;
  }

  protected static class WrappedEventCommand extends CommandBase {
    private final Command command;

    protected WrappedEventCommand(Command command) {
      CommandGroupBase.requireUngrouped(command);

      this.command = command;
    }

    @Override
    public void initialize() {
      command.initialize();
    }

    @Override
    public void execute() {
      command.execute();
    }

    @Override
    public void end(boolean interrupted) {
      command.end(interrupted);
    }

    @Override
    public boolean isFinished() {
      return command.isFinished();
    }

    public Set<Subsystem> getSoftRequirements() {
      return command.getRequirements();
    }
  }
}
