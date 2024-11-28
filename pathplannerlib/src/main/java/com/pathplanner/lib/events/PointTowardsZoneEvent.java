package com.pathplanner.lib.events;

import static edu.wpi.first.units.Units.Seconds;

import edu.wpi.first.units.measure.Time;

/** Event for setting the value of a point towards zone trigger */
public class PointTowardsZoneEvent extends Event {
  private final String name;
  private final boolean active;

  /**
   * Create an event for changing the value of a point towards zone trigger
   *
   * @param timestamp The trajectory timestamp of this event
   * @param name The name of the point towards zone trigger to control
   * @param active Should the trigger be activated by this event
   */
  public PointTowardsZoneEvent(double timestamp, String name, boolean active) {
    super(timestamp);
    this.name = name;
    this.active = active;
  }

  /**
   * Create an event for changing the value of a point towards zone trigger
   *
   * @param timestamp The trajectory timestamp of this event
   * @param name The name of the point towards zone trigger to control
   * @param active Should the trigger be activated by this event
   */
  public PointTowardsZoneEvent(Time timestamp, String name, boolean active) {
    this(timestamp.in(Seconds), name, active);
  }

  /**
   * Handle this event
   *
   * @param eventScheduler Reference to the EventScheduler running this event
   */
  @Override
  public void handleEvent(EventScheduler eventScheduler) {
    PointTowardsZoneTrigger.setWithinZone(name, active);
  }

  @Override
  public void cancelEvent(EventScheduler eventScheduler) {
    if (!active) {
      // Ensure this zone's condition gets set to false
      PointTowardsZoneTrigger.setWithinZone(name, false);
    }
  }

  @Override
  public Event copyWithTimestamp(double timestampSeconds) {
    return new PointTowardsZoneEvent(timestampSeconds, name, active);
  }
}
