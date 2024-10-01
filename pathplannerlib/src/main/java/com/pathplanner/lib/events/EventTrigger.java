package com.pathplanner.lib.events;

import edu.wpi.first.wpilibj2.command.button.Trigger;

/**
 * A trigger that will be controlled by the placement of event markers/zones in a
 * PathPlannerTrajectory
 */
public class EventTrigger extends Trigger {
  /**
   * Create a new EventTrigger
   *
   * @param name The name of the event. This will be the name of the event marker in the GUI
   */
  public EventTrigger(String name) {
    super(EventScheduler.getEventLoop(), EventScheduler.pollCondition(name));
  }
}
