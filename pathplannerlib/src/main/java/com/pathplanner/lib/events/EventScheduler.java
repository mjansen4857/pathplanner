package com.pathplanner.lib.events;

import com.pathplanner.lib.path.EventMarker;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import edu.wpi.first.wpilibj.event.EventLoop;
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
  private static final EventLoop eventLoop = new EventLoop();

  private final Map<Command, Boolean> eventCommands;
  private final Queue<Event> upcomingEvents;

  /** Create a new EventScheduler */
  public EventScheduler() {
    this.eventCommands = new HashMap<>();
    this.upcomingEvents =
        new PriorityQueue<>(Comparator.comparingDouble(Event::getTimestampSeconds));
  }

  /**
   * Initialize the EventScheduler for the given trajectory. This should be called from the
   * initialize method of the command running this scheduler.
   *
   * @param trajectory The trajectory this scheduler should handle events for
   */
  public void initialize(PathPlannerTrajectory trajectory) {
    eventCommands.clear();
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
    while (!upcomingEvents.isEmpty() && time >= upcomingEvents.peek().getTimestampSeconds()) {
      upcomingEvents.poll().handleEvent(this);
    }

    // Run currently running commands
    for (var entry : eventCommands.entrySet()) {
      if (!entry.getValue()) {
        continue;
      }

      entry.getKey().execute();
      if (entry.getKey().isFinished()) {
        entry.getKey().end(false);
        eventCommands.put(entry.getKey(), false);
      }
    }

    eventLoop.poll();
  }

  /**
   * End commands currently/events currently being handled by this scheduler. This should be called
   * from the end method of the command running this scheduler.
   */
  public void end() {
    // Cancel all currently running commands
    for (var entry : eventCommands.entrySet()) {
      if (!entry.getValue()) {
        continue;
      }

      entry.getKey().end(true);
    }

    // Cancel any unhandled events
    for (Event e : upcomingEvents) {
      e.cancelEvent(this);
    }

    eventCommands.clear();
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
      if (m.command() != null) {
        allReqs.addAll(m.command().getRequirements());
      }
    }

    return allReqs;
  }

  /**
   * Get the event loop used to poll global event triggers
   *
   * @return Event loop that polls global event triggers
   */
  protected static EventLoop getEventLoop() {
    return eventLoop;
  }

  /**
   * Schedule a command on this scheduler. This will cancel other commands that share requirements
   * with the given command.
   *
   * @param command The command to schedule
   */
  protected void scheduleCommand(Command command) {
    // Check for commands that should be cancelled by this command
    for (var entry : eventCommands.entrySet()) {
      if (!entry.getValue()) {
        continue;
      }

      if (!Collections.disjoint(entry.getKey().getRequirements(), command.getRequirements())) {
        cancelCommand(entry.getKey());
      }
    }

    command.initialize();
    eventCommands.put(command, true);
  }

  /**
   * Cancel a command on this scheduler.
   *
   * @param command The command to cancel
   */
  protected void cancelCommand(Command command) {
    if (!eventCommands.containsKey(command) || !eventCommands.get(command)) {
      // Command is not currently running
      return;
    }

    command.end(true);
    eventCommands.put(command, false);
  }
}
