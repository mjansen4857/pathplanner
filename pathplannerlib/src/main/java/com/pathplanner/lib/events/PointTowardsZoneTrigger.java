package com.pathplanner.lib.events;

import java.util.HashMap;
import java.util.function.BooleanSupplier;

import org.wpilib.command3.Trigger;

import com.pathplanner.lib.commands.FollowPathCommand;
import com.pathplanner.lib.commands.PathPlannerAuto;

/**
 * A trigger that will be controlled by the robot entering/leaving a point
 * towards zone
 */
public class PointTowardsZoneTrigger extends Trigger {

  private static final HashMap<String, Boolean> zoneConditions = new HashMap<>();

  /**
   * Create a new PointTowardsZoneTrigger. This is only polled while the given
   * {@link PathPlannerAuto} is running.
   *
   * @param auto The auto whose loop and scheduler we bind to
   * @param name The name of the point towards zone
   */
  public PointTowardsZoneTrigger(PathPlannerAuto auto, String name) {
    super(auto.getAutoScheduler(), auto.getAutoLoop(), pollCondition(name));
  }

  /**
   * Create a new PointTowardsZoneTrigger. This is only polled while the given
   * {@link FollowPathCommand} is running.
   *
   * @param cmd  The path-following command whose loop and scheduler we bind to
   * @param name The name of the point towards zone
   */
  public PointTowardsZoneTrigger(FollowPathCommand cmd, String name) {
    super(cmd.getEventScheduler(), cmd.getEventLoop(), pollCondition(name));
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
   * @param name       The name of the condition
   * @param withinZone Is the robot within the point towards zone with the given
   *                   name
   */
  protected static void setWithinZone(String name, boolean withinZone) {
    zoneConditions.put(name, withinZone);
  }
}
