package com.pathplanner.lib.events;

import static org.wpilib.units.Units.Seconds;

import org.wpilib.command3.Command;
import org.wpilib.command3.Scheduler;
import org.wpilib.units.measure.Time;

/** Event that will schedule a command within the EventScheduler */
public class ScheduleCommandEvent extends Event {

  private final Command command;

  /**
   * Create an event to schedule a command
   *
   * @param timestamp The trajectory timestamp for this event
   * @param command The command to schedule
   */
  public ScheduleCommandEvent(double timestamp, Command command) {
    super(timestamp);
    this.command = command;
  }

  /**
   * Create an event to schedule a command
   *
   * @param timestamp The trajectory timestamp for this event
   * @param command The command to schedule
   */
  public ScheduleCommandEvent(Time timestamp, Command command) {
    this(timestamp.in(Seconds), command);
  }

  @Override
  public void handleEvent(Scheduler scheduler) {
    scheduler.schedule(command);
  }

  @Override
  public void cancelEvent(Scheduler scheduler) {
    // Do nothing
  }

  @Override
  public Event copyWithTimestamp(double timestampSeconds) {
    return new ScheduleCommandEvent(timestampSeconds, command);
  }
}
