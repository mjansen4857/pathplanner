package com.pathplanner.lib.events;

import java.util.HashMap;
import java.util.function.BooleanSupplier;

import org.wpilib.command3.Scheduler;
import org.wpilib.command3.Trigger;
import org.wpilib.event.EventLoop;

/** A trigger that will be controlled by the robot entering/leaving a point towards zone */
public class PointTowardsZoneTrigger extends Trigger {

  private static final HashMap<String, Boolean> zoneConditions = new HashMap<>();

  /**
   * Create a new PointTowardsZoneTrigger. This will run on the EventScheduler's event loop, which
   * will be polled any time a path following command is running.
   *
   * @param name The name of the point towards zone
   */
  public PointTowardsZoneTrigger(Scheduler scheduler, EventLoop eventLoop, String name) {
    super(scheduler, eventLoop, pollCondition(name));
  }

  /**
   * Create a new PointTowardsZoneTrigger that gets polled by the given event loop instead of the
   * EventScheduler
   *
   * @param eventLoop The event loop to poll this trigger
   * @param name The name of the point towards zone
   */
  public PointTowardsZoneTrigger(EventLoop eventLoop, String name) {
    super(Scheduler.getDefault(), eventLoop, pollCondition(name));
  }

  /**
   * Create a boolean supplier that will poll a condition.
   *
   * @param name The name of the point towards zone
   * @return A boolean supplier to poll the zone's condition
   */
  private static BooleanSupplier pollCondition(String name) {
    // Ensure there is a condition in the map for this name
    if (!zoneConditions.containsKey(name)) {
      zoneConditions.put(name, false);
    }
    return () -> zoneConditions.get(name);
  }

  /**
   * Set the value of a zone condition
   *
   * @param name The name of the condition
   * @param withinZone Is the robot within the point towards zone with the given name
   */
  protected static void setWithinZone(String name, boolean withinZone) {
    zoneConditions.put(name, withinZone);
  }
}
