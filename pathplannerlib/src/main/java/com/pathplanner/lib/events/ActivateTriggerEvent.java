package com.pathplanner.lib.events;

/** Event for activating a trigger */
public class ActivateTriggerEvent extends Event {
  private final String name;

  /**
   * Create an event for changing the value of a named trigger
   *
   * @param timestamp The trajectory timestamp of this event
   * @param name The name of the trigger to control
   */
  public ActivateTriggerEvent(double timestamp, String name) {
    super(timestamp);
    this.name = name;
  }

  /**
   * Handle this event
   *
   * @param eventScheduler Reference to the EventScheduler running this event
   */
  @Override
  public void handleEvent(EventScheduler eventScheduler) {
    EventScheduler.setCondition(name, true);
  }

  @Override
  public void cancelEvent(EventScheduler eventScheduler) {
    // Do nothing
  }

  @Override
  public Event copyWithTimestamp(double timestamp) {
    return new ActivateTriggerEvent(timestamp, name);
  }
}
