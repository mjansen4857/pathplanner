package com.pathplanner.lib.events;

import com.pathplanner.lib.path.EventMarker;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import edu.wpi.first.wpilibj.event.EventLoop;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.util.*;
import java.util.function.BooleanSupplier;

/**
 * Scheduler for running events while following a trajectory
 *
 * <p>Note: The command that is running this scheduler must have the requirements of all commands
 * that will be run during the path being followed.
 */
public class EventScheduler {
  private static final EventLoop eventLoop = new EventLoop();
  private static final HashMap<String, Boolean> eventConditions = new HashMap<>();

  private final Map<Command, Boolean> eventCommands;
  private final Queue<Event> upcomingEvents;

  /** Create a new EventScheduler */
  public EventScheduler() {
    this.eventCommands = new HashMap<>();
    this.upcomingEvents = new PriorityQueue<>(Comparator.comparingDouble(Event::getTimestamp));
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
    while (!upcomingEvents.isEmpty() && time >= upcomingEvents.peek().getTimestamp()) {
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
      allReqs.addAll(m.getCommand().getRequirements());
    }

    return allReqs;
  }

  /**
   * Get the event loop used to poll event triggers
   *
   * @return Event loop that polls event triggers
   */
  protected static EventLoop getEventLoop() {
    return eventLoop;
  }

  /**
   * Create a boolean supplier that will poll a condition. This is used to create EventTriggers
   *
   * @param name The name of the event
   * @return A boolean supplier to poll the event's condition
   */
  protected static BooleanSupplier pollCondition(String name) {
    // Ensure there is a condition in the map for this name
    if (!eventConditions.containsKey(name)) {
      eventConditions.put(name, false);
    }

    return () -> eventConditions.get(name);
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

  /**
   * Set the value of a named condition
   *
   * @param name The name of the condition
   * @param value The value of the condition
   */
  protected void setCondition(String name, boolean value) {
    eventConditions.put(name, value);
  }
}
