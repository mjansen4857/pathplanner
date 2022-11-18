package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import edu.wpi.first.wpilibj2.command.*;
import java.util.*;

public abstract class BaseAutoBuilder {
  protected final HashMap<String, Command> eventMap;

  /**
   * Construct a BaseAutoBuilder
   *
   * @param eventMap Event map for triggering events at markers
   */
  protected BaseAutoBuilder(HashMap<String, Command> eventMap) {
    this.eventMap = eventMap;
  }

  /**
   * Method that will provide a path following command to the auto builder. This will be used to
   * create more complex command groups.
   *
   * <p>Override this to create auto builders for your custom path following commands.
   *
   * @param trajectory The trajectory to follow
   * @return A path following command for the given trajectory
   */
  protected abstract CommandBase getPathFollowingCommand(PathPlannerTrajectory trajectory);

  /**
   * Create a command group safe path following command that will trigger events as it goes. Use
   * this instead of adding the path following commands to your command group directly.
   *
   * @param trajectory The trajectory to follow
   * @return Command group that will follow the trajectory and trigger events
   */
  public CommandBase followPathWithEvents(PathPlannerTrajectory trajectory) {
    return new ParallelDeadlineGroup(getPathFollowingCommand(trajectory), eventGroup(trajectory));
  }

  /**
   * Create a parallel command group that will handle triggering events. This group will consist of
   * a sequential command group for each event that will: wait until it is time to trigger the
   * event, cancel any previous events that share requirements with the event, then run the event
   * command.
   *
   * @param trajectory The trajectory to trigger events for
   * @return Command group that will trigger events. To be used alongside a path following command
   */
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
