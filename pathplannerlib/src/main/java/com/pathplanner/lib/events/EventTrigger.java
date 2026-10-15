package com.pathplanner.lib.events;

import java.util.HashMap;
import java.util.function.BooleanSupplier;

import org.wpilib.command3.Trigger;

import com.pathplanner.lib.commands.FollowPathCommand;
import com.pathplanner.lib.commands.PathPlannerAuto;

/**
 * A trigger that will be controlled by the placement of event markers/zones in
 * a PathPlannerTrajectory
 */
public class EventTrigger extends Trigger {

  private static final HashMap<String, Boolean> eventConditions = new HashMap<>();

  /**
   * Create a new EventTrigger. This is only polled while the given
   * {@link PathPlannerAuto} is running.
   *
   * @param auto The PathPlannerAuto whose loop and scheduler we bind to
   * @param name The name of the point towards zone
   */
  public EventTrigger(PathPlannerAuto auto, String name) {
    super(auto.getAutoScheduler(), auto.getAutoLoop(), pollCondition(name));
  }

  /**
   * Create a new EventTrigger. This is only polled while the given
   * {@link FollowPathCommand} is running.
   *
   * @param cmd  The FollowPathCommand whose loop and scheduler we bind to
   * @param name The name of the point towards zone
   */
  public EventTrigger(FollowPathCommand cmd, String name) {
    super(cmd.getEventScheduler(), cmd.getEventLoop(), pollCondition(name));
  }

  /**
   * Create a boolean supplier that will poll a condition.
   *
   * @param name The name of the event
   * @return A boolean supplier to poll the event's condition
   */
  private static BooleanSupplier pollCondition(String name) {
    // Ensure there is a condition in the map for this name
    if (!eventConditions.containsKey(name)) {
      eventConditions.put(name, false);
    }
    return () -> eventConditions.get(name);
  }

  /**
   * Set the value of an event condition
   *
   * @param name  The name of the condition
   * @param value The value of the condition
   */
  protected static void setCondition(String name, boolean value) {
    eventConditions.put(name, value);
  }
}
