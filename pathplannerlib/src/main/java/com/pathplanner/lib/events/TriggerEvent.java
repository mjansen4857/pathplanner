package com.pathplanner.lib.events;

import static edu.wpi.first.units.Units.Seconds;

import edu.wpi.first.units.measure.Time;

/** Event for setting the value of an event trigger */
public class TriggerEvent extends Event {
  private final String name;
  private final boolean active;

  /**
   * Create an event for changing the value of a named trigger
   *
   * @param timestamp The trajectory timestamp of this event
   * @param name The name of the trigger to control
   * @param active Should the trigger be activated by this event
   */
  public TriggerEvent(double timestamp, String name, boolean active) {
    super(timestamp);
    this.name = name;
    this.active = active;
  }

  /**
   * Create an event for changing the value of a named trigger
   *
   * @param timestamp The trajectory timestamp of this event
   * @param name The name of the trigger to control
   * @param active Should the trigger be activated by this event
   */
  public TriggerEvent(Time timestamp, String name, boolean active) {
    this(timestamp.in(Seconds), name, active);
  }

  /**
   * Get the event name for this event
   *
   * @return The event name
   */
  public String getEventName() {
    return name;
  }

  /**
   * Get whether this event will set the trigger high or low
   *
   * @return Value of the trigger
   */
  public boolean getValue() {
    return active;
  }

  /**
   * Handle this event
   *
   * @param eventScheduler Reference to the EventScheduler running this event
   */
  @Override
  public void handleEvent(EventScheduler eventScheduler) {
    EventTrigger.setCondition(name, active);
  }

  @Override
  public void cancelEvent(EventScheduler eventScheduler) {
    if (!active) {
      // Ensure this event's condition gets set to false
      EventTrigger.setCondition(name, false);
    }
  }

  @Override
  public Event copyWithTimestamp(double timestampSeconds) {
    return new TriggerEvent(timestampSeconds, name, active);
  }
}
