package com.pathplanner.lib.events;

/** Base class for an event to be handled while path following */
public abstract class Event {
  private double timestamp;

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
   * Set the trajectory timestamp of this event
   *
   * @param timestamp Timestamp of this event along the trajectory
   */
  public void setTimestamp(double timestamp) {
    this.timestamp = timestamp;
  }

  /**
   * Handle this event
   *
   * @param eventScheduler Reference to the EventScheduler handling this event
   */
  public abstract void handleEvent(EventScheduler eventScheduler);

  /**
   * Cancel this event. This will be called if a path following command ends before this event gets
   * handled.
   *
   * @param eventScheduler Reference to the EventScheduler handling this event
   */
  public abstract void cancelEvent(EventScheduler eventScheduler);

  /**
   * Copy this event with a different timestamp
   *
   * @param timestamp The new timestamp
   * @return Copied event with new time
   */
  public abstract Event copyWithTimestamp(double timestamp);
}
