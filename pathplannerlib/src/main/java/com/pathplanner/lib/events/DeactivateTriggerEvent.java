package com.pathplanner.lib.events;

/** Event for deactivating a trigger */
public class DeactivateTriggerEvent extends Event {
  private final String name;

  /**
   * Create an event for changing the value of a named trigger
   *
   * @param timestamp The trajectory timestamp of this event
   * @param name The name of the trigger to control
   */
  public DeactivateTriggerEvent(double timestamp, String name) {
    super(timestamp);
    this.name = name;
  }

  @Override
  public void handleEvent(EventScheduler eventScheduler) {
    EventScheduler.setCondition(name, false);
  }

  @Override
  public void cancelEvent(EventScheduler eventScheduler) {
    // Ensure the condition gets set to false
    EventScheduler.setCondition(name, false);
  }

  @Override
  public Event copyWithTimestamp(double timestamp) {
    return new DeactivateTriggerEvent(timestamp, name);
  }
}
