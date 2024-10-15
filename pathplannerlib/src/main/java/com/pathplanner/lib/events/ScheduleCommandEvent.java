package com.pathplanner.lib.events;

import static edu.wpi.first.units.Units.Seconds;

import edu.wpi.first.units.measure.Time;
import edu.wpi.first.wpilibj2.command.Command;

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
  public void handleEvent(EventScheduler eventScheduler) {
    eventScheduler.scheduleCommand(command);
  }

  @Override
  public void cancelEvent(EventScheduler eventScheduler) {
    // Do nothing
  }

  @Override
  public Event copyWithTimestamp(double timestampSeconds) {
    return new ScheduleCommandEvent(timestampSeconds, command);
  }
}
