package com.pathplanner.lib.events;

import static edu.wpi.first.units.Units.Seconds;

import edu.wpi.first.units.measure.Time;

/** Base class for an event to be handled while path following */
public abstract class Event {
  private double timestamp;

  /**
   * Create a new event
   *
   * @param timestampSeconds The trajectory timestamp this event should be handled at
   */
  public Event(double timestampSeconds) {
    this.timestamp = timestampSeconds;
  }

  /**
   * Create a new event
   *
   * @param timestamp The trajectory timestamp this event should be handled at
   */
  public Event(Time timestamp) {
    this(timestamp.in(Seconds));
  }

  /**
   * Get the trajectory timestamp for this event
   *
   * @return Trajectory timestamp, in seconds
   */
  public double getTimestampSeconds() {
    return timestamp;
  }

  /**
   * Get the trajectory timestamp for this event
   *
   * @return Trajectory timestamp
   */
  public Time getTimestamp() {
    return Seconds.of(timestamp);
  }

  /**
   * Set the trajectory timestamp of this event
   *
   * @param timestampSeconds Timestamp of this event along the trajectory
   */
  public void setTimestamp(double timestampSeconds) {
    this.timestamp = timestampSeconds;
  }

  /**
   * Set the trajectory timestamp of this event
   *
   * @param timestamp Timestamp of this event along the trajectory
   */
  public void setTimestamp(Time timestamp) {
    setTimestamp(timestamp.in(Seconds));
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
   * @param timestampSeconds The new timestamp
   * @return Copied event with new time
   */
  public abstract Event copyWithTimestamp(double timestampSeconds);

  /**
   * Copy this event with a different timestamp
   *
   * @param timestamp The new timestamp
   * @return Copied event with new time
   */
  public Event copyWithTimestamp(Time timestamp) {
    return copyWithTimestamp(timestamp.in(Seconds));
  }
}
