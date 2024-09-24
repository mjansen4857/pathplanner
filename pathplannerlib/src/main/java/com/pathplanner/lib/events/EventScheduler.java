package com.pathplanner.lib.events;

import com.pathplanner.lib.path.EventMarker;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.*;

/**
 * Scheduler for running events while following a trajectory
 *
 * <p>Note: The command that is running this scheduler must have the requirements of all commands
 * that will be run during the path being followed.
 */
public class EventScheduler {
  private final Set<Command> runningEventCommands;
  private final Queue<Event> upcomingEvents;

  /** Create a new EventScheduler */
  public EventScheduler() {
    this.runningEventCommands = new HashSet<>();
    this.upcomingEvents = new LinkedList<>();
  }

  /**
   * Initialize the EventScheduler for the given trajectory. This should be called from the
   * initialize method of the command running this scheduler.
   *
   * @param trajectory The trajectory this scheduler should handle events for
   */
  public void initialize(PathPlannerTrajectory trajectory) {
    runningEventCommands.clear();
    upcomingEvents.clear();

    upcomingEvents.addAll(trajectory.getEvents());
  }

  /**
   * Run the scheduler. This should be called from the execute method of the command running this
   * scheduler.
   *
   * @param time The current time along the trajectory
   */
  public void execute(double time) {
    // Check for events that should be handled this loop
    while (!upcomingEvents.isEmpty() && time >= upcomingEvents.peek().getTimestamp()) {
      upcomingEvents.poll().handleEvent(this);
    }

    // Run currently running commands
    for (var i = runningEventCommands.iterator(); i.hasNext(); ) {
      Command command = i.next();
      command.execute();

      if (command.isFinished()) {
        command.end(false);
        i.remove();
      }
    }
  }

  /**
   * End commands currently being run by this scheduler. This should be called from the end method
   * of the command running this scheduler.
   */
  public void end() {
    // Cancel all currently running commands
    for (Command command : runningEventCommands) {
      command.end(true);
    }

    runningEventCommands.clear();
    upcomingEvents.clear();
  }

  /**
   * Get the event requirements for the given path
   *
   * @param path The path to get all requirements for
   * @return Set of event requirements for the given path
   */
  public static Set<Subsystem> getSchedulerRequirements(PathPlannerPath path) {
    Set<Subsystem> allReqs = new HashSet<>();

    for (EventMarker m : path.getEventMarkers()) {
      allReqs.addAll(m.getCommand().getRequirements());
    }

    return allReqs;
  }

  /**
   * Schedule a command on this scheduler. This will cancel other commands that share requirements
   * with the given command.
   *
   * @param command The command to schedule
   */
  protected void scheduleCommand(Command command) {
    // Check for commands that should be cancelled by this command
    for (Command other : runningEventCommands) {
      if (!Collections.disjoint(other.getRequirements(), command.getRequirements())) {
        cancelCommand(command);
      }
    }

    command.initialize();
    runningEventCommands.add(command);
  }

  /**
   * Cancel a command on this scheduler.
   *
   * @param command The command to cancel
   */
  protected void cancelCommand(Command command) {
    if (!runningEventCommands.contains(command)) {
      // Command is not currently running
      return;
    }

    command.end(true);
    runningEventCommands.remove(command);
  }
}
