package com.pathplanner.lib.events;

/** Base class for an event to be handled while path following */
public abstract class Event {
  private final double timestamp;

  /**
   * Create a new event
   *
   * @param timestamp The trajectory timestamp this event should be handled at
   */
  public Event(double timestamp) {
    this.timestamp = timestamp;
  }

  /**
   * Get the trajectory timestamp for this event
   *
   * @return Trajectory timestamp, in seconds
   */
  public double getTimestamp() {
    return timestamp;
  }

  /**
   * Handle this event
   *
   * @param eventScheduler Reference to the EventScheduler running this event
   */
  public abstract void handleEvent(EventScheduler eventScheduler);
}
