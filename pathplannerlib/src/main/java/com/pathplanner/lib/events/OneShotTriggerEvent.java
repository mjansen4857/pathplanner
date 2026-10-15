package com.pathplanner.lib.events;

import static org.wpilib.units.Units.Seconds;

import org.wpilib.command3.Command;
import org.wpilib.command3.Scheduler;
import org.wpilib.units.measure.Time;

/** Event that will activate a trigger, then deactivate it the next loop */
public class OneShotTriggerEvent extends Event {

  private final String name;

  private final Command resetCommand;

  /**
   * Create an event for activating a trigger, then deactivating it the next loop
   *
   * @param timestamp The trajectory timestamp of this event
   * @param name The name of the trigger to control
   */
  public OneShotTriggerEvent(double timestamp, String name) {
    super(timestamp);
    this.name = name;
    this.resetCommand = Command.noRequirements(coro -> {
      coro.yield();
      EventTrigger.setCondition(name, false);
    }).named("[PathPlanner] reset command for OneShotTriggerEvent '" + name + "'");
  }

  /**
   * Create an event for activating a trigger, then deactivating it the next loop
   *
   * @param timestamp The trajectory timestamp of this event
   * @param name The name of the trigger to control
   */
  public OneShotTriggerEvent(Time timestamp, String name) {
    this(timestamp.in(Seconds), name);
  }

  /**
   * Get the event name for this event
   *
   * @return The event name
   */
  public String getEventName() {
    return name;
  }

  @Override
  public void handleEvent(Scheduler scheduler) {
    EventTrigger.setCondition(name, true);

    // We schedule this command with the main command scheduler so that it is guaranteed to be run
    // in its entirety, since the EventScheduler could cancel this command before it finishes
    Scheduler.getDefault().schedule(resetCommand);
  }

  @Override
  public void cancelEvent(Scheduler scheduler) {
    // Do nothing
  }

  @Override
  public Event copyWithTimestamp(double timestampSeconds) {
    return new OneShotTriggerEvent(timestampSeconds, name);
  }
}
