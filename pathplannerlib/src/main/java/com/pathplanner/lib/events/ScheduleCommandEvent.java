package com.pathplanner.lib.events;

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

  @Override
  public void handleEvent(EventScheduler eventScheduler) {
    eventScheduler.scheduleCommand(command);
  }

  @Override
  public void cancelEvent(EventScheduler eventScheduler) {
    // Do nothing
  }

  @Override
  public Event copyWithTimestamp(double timestamp) {
    return new ScheduleCommandEvent(timestamp, command);
  }
}
