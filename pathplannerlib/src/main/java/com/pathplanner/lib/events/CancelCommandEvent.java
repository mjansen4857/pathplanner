package com.pathplanner.lib.events;

import static edu.wpi.first.units.Units.Seconds;

import edu.wpi.first.units.measure.Time;
import edu.wpi.first.wpilibj2.command.Command;

/** Event that will cancel a command within the EventScheduler */
public class CancelCommandEvent extends Event {
  private final Command command;

  /**
   * Create an event to cancel a command
   *
   * @param timestamp The trajectory timestamp for this event
   * @param command The command to cancel
   */
  public CancelCommandEvent(double timestamp, Command command) {
    super(timestamp);
    this.command = command;
  }

  /**
   * Create an event to cancel a command
   *
   * @param timestamp The trajectory timestamp for this event
   * @param command The command to cancel
   */
  public CancelCommandEvent(Time timestamp, Command command) {
    this(timestamp.in(Seconds), command);
  }

  @Override
  public void handleEvent(EventScheduler eventScheduler) {
    eventScheduler.cancelCommand(command);
  }

  @Override
  public void cancelEvent(EventScheduler eventScheduler) {
    // Do nothing, the event scheduler will already cancel all commands
  }

  @Override
  public Event copyWithTimestamp(double timestampSeconds) {
    return new CancelCommandEvent(timestampSeconds, command);
  }
}
